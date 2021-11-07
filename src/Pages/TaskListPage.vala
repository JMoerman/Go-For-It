/* Copyright 2018-2019 Go For It! developers
*
* This file is part of Go For It!.
*
* Go For It! is free software: you can redistribute it
* and/or modify it under the terms of version 3 of the
* GNU General Public License as published by the Free Software Foundation.
*
* Go For It! is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with Go For It!. If not, see http://www.gnu.org/licenses/.
*/

using GOFI.TXT;

/**
 * A widget containing a TaskList and its widgets and the TimerView.
 */
class GOFI.TaskListPage : Gtk.Grid {
    // The list that is currently shown
    private TaskList _shown_list = null;
    // The list used by the timer
    private TaskList _active_list = null;
    private TaskTimer task_timer;

    /* Various GTK Widgets */
    private Gtk.Stack activity_stack;
    private ViewSwitcher activity_switcher;
    private Gtk.Stack switcher_stack;

    private Gtk.Widget first_page;
    private TimerView timer_view;
    private Gtk.Widget last_page;

    public TaskList? shown_list {
        get {
            return _shown_list;
        }
    }

    public TaskList? active_list {
        get {
            return _active_list;
        }
    }

    public bool showing_timer {
        get;
        private set;
        default = false;
    }

    public signal void removing_list ();

    [Signal (action = true)]
    public virtual signal void switch_to_next () {
        TodoTask? next;
        if (_shown_list == null) {
            return;
        }
        if (_active_list == null) {
            var shown_list_task = _shown_list.get_next (null);
            if (shown_list_task != null) {
                switch_to_list_with_task (_shown_list, shown_list_task);
            }
            return;
        }
        next = _active_list.get_next (task_timer.active_task);

        task_timer.active_task = next;
    }

    [Signal (action = true)]
    public virtual signal void switch_to_prev () {
        TodoTask? prev;
        if (_shown_list == null) {
            return;
        }
        if (_active_list == null) {
            var shown_list_task = _shown_list.get_prev (null);
            if (shown_list_task != null) {
                switch_to_list_with_task (_shown_list, shown_list_task);
            }
            return;
        }

        prev = _active_list.get_prev (task_timer.active_task);

        task_timer.active_task = prev;
    }

    public void propagate_filter_action () {
        var visible_child = activity_stack.get_visible_child ();
        unowned ObjectClass? oc = null;
        if (visible_child == first_page) {
            oc = first_page.get_class ();
        } else if (visible_child == last_page) {
            oc = last_page.get_class ();
        }
        if (oc != null) {
            var sc = kbsettings.get_shortcut ("filter");
            Gtk.BindingSet.by_class (oc).activate (sc.key, sc.modifier, visible_child);
        }
    }

    [Signal (action = true)]
    public virtual signal void mark_task_done () {
        var visible_child = activity_stack.get_visible_child ();
        if (visible_child == first_page) {
            warning ("stub!");
        } else if (visible_child == timer_view) {
            bool was_running = task_timer.running;
            task_timer.stop ();
            on_task_done ();

            // Resume break, only keep stopped when a task is active
            if (was_running) {
                if (task_timer.break_active || !settings.reset_timer_on_task_switch) {
                    task_timer.start ();
                }
            }
        }
    }

    /**
     * The constructor of the TaskListPage class.
     */
    public TaskListPage (TaskTimer task_timer) {
        this.task_timer = task_timer;

        this.orientation = Gtk.Orientation.VERTICAL;
        initial_setup ();
        task_timer.timer_stopped.connect (on_timer_stopped);
        get_style_context ().add_class ("task-layout");
    }

    /**
     * Initializes everything that doesn't depend on a TodoTask.
     */
    private void initial_setup () {
        /* Instantiation of available widgets */
        activity_stack = new Gtk.Stack ();
        switcher_stack = new Gtk.Stack ();
        activity_switcher = new ViewSwitcher ();
        timer_view = new TimerView (task_timer);
        var activity_label = new Gtk.Label (_("Lists"));
        activity_label.get_style_context ().add_class ("title");

        // Activity Stack + Switcher
        activity_switcher.halign = Gtk.Align.CENTER;
        activity_switcher.icon_size = Gtk.IconSize.LARGE_TOOLBAR;
        activity_switcher.append ("primary", _("To-Do"), "go-to-list-symbolic");
        activity_switcher.append ("timer", _("Timer"), GOFI.ICON_NAME);
        activity_switcher.append ("secondary", _("Done"), "go-to-done");
        activity_stack.set_transition_type (
            Gtk.StackTransitionType.SLIDE_LEFT_RIGHT
        );
        switcher_stack.set_transition_type (
            Gtk.StackTransitionType.SLIDE_UP_DOWN
        );
        activity_switcher.icon_size = settings.toolbar_icon_size;
        activity_switcher.show_icons = settings.switcher_use_icons;

        activity_switcher.notify["selected-item"].connect (
            on_activity_switcher_selected_item_changed
        );
        settings.toolbar_icon_size_changed.connect (on_icon_size_changed);
        settings.switcher_use_icons_changed.connect (on_switcher_use_icons);
        timer_view.done_btn_clicked.connect (on_task_done);

        switcher_stack.add_named (activity_switcher, "switcher");
        switcher_stack.add_named (activity_label, "label");
        this.add (activity_stack);
    }

    private void on_activity_switcher_selected_item_changed () {
        var selected = activity_switcher.selected_item;
        activity_stack.set_visible_child_name (selected);
        if (selected == "timer") {
            timer_view.set_focus ();
            showing_timer = true;
        } else {
            showing_timer = false;
        }
    }

    public Gtk.Widget get_switcher () {
        return switcher_stack;
    }

    public void show_switcher (bool show) {
        if (show) {
            switcher_stack.set_visible_child_name ("switcher");
        } else {
            switcher_stack.set_visible_child_name ("label");
        }
    }

    public void action_add_task () {
        activity_switcher.selected_item = "primary";
        _shown_list.add_task_shortcut ();
    }

    public bool switch_page_left () {
        switch (activity_switcher.selected_item) {
            case "timer":
                activity_switcher.selected_item = "primary";
                return false;
            case "secondary":
                activity_switcher.selected_item = "timer";
                return false;
            default:
                return true;
        }
    }

    public bool switch_page_right () {
        switch (activity_switcher.selected_item) {
            case "primary":
                activity_switcher.selected_item = "timer";
                return false;
            case "timer":
                activity_switcher.selected_item = "secondary";
                return false;
            default:
                return true;
        }
    }

    /**
     * Adds the widgets from task_list as well as timer_view to the stack.
     */
    private void add_widgets () {
        string first_page_name;
        string second_page_name;

        disconnect_first_page_signals ();

        /* Instantiation of the Widgets */
        first_page = _shown_list.get_primary_page (out first_page_name);
        last_page = _shown_list.get_secondary_page (out second_page_name);

        if (first_page_name == null) {
           first_page_name = _("To-Do");
        }
        if (second_page_name == null) {
           second_page_name = _("Done");
        }

        // Add widgets to the activity stack
        activity_stack.add_titled (first_page, "primary", first_page_name);
        activity_stack.add_titled (timer_view, "timer", _("Timer"));
        activity_stack.add_titled (last_page, "secondary", second_page_name);

        if (task_timer.running) {
            // Otherwise no task will be displayed in the timer view
            task_timer.update_active_task ();

            // Otherwise it won't switch
            timer_view.show ();

            activity_switcher.selected_item = "timer";
            activity_stack.visible_child = timer_view;
        }
        else {
            first_page.show ();

            activity_switcher.selected_item = "primary";
            activity_stack.visible_child = first_page;
        }

        connect_first_page_signals ();
    }

    private void connect_first_page_signals () {
        var first_page_cont = first_page as Gtk.Container;
        if (first_page_cont != null) {
            first_page_cont.set_focus_child.connect (on_first_page_focus);
        }
    }

    private void disconnect_first_page_signals () {
        var first_page_cont = first_page as Gtk.Container;
        if (first_page_cont != null) {
            first_page_cont.set_focus_child.disconnect (on_first_page_focus);
        }
    }

    private void update_timer_values (TimerSchedule? sched, int reminder_t) {
        if (sched != null && !sched.valid) {
            sched = null;
        }
        task_timer.schedule = sched;
        task_timer.reminder_time = reminder_t;
    }

    private void on_task_done () {
        var task = task_timer.active_task;
        if (unlikely(task == null)) {
            critical ("on_task_done called while no timer task has been picked!");
            return;
        }
        var next = _active_list.get_next (task);
        if (next == task) {
            task_timer.active_task = null;
        } else {
            task_timer.active_task = next;
        }
        _active_list.mark_done (task);
    }

    /**
     * If the first page receives focus, check if the selected task needs to be
     * refreshed
     */
    private void on_first_page_focus (Gtk.Widget? child) {
        // if (child != null && shown_list != active_list) {
        //     // Task may be stale, lets refresh the selected task if necessary
        //     on_selected_task_changed ();
        // }
    }

    private void on_timer_stopped (DateTime start_time, uint runtime) {
        if (task_timer.break_active) {
            return;
        }
        var active_task = task_timer.active_task;
        var stop_time = new DateTime.now_utc ();
        activity_log.log_task (
            _active_list.list_info.name,
            active_task.description,
            start_time,
            runtime,
            stop_time
        );
        var active_list_log_file = _active_list.get_log_file ();
        if (active_list_log_file != null) {
            activity_log.log_task_in_file (
                active_list_log_file,
                _active_list.list_info.name,
                active_task.description,
                start_time,
                runtime,
                stop_time
            );
        }
    }

    private void on_icon_size_changed (Gtk.IconSize size) {
        activity_switcher.icon_size = size;
    }

    private void on_switcher_use_icons (bool show_icons) {
        activity_switcher.show_icons = show_icons;
    }

    public void show_timer () {
        activity_switcher.selected_item = "timer";
    }

    /**
     * Changes which task list is shown.
     * If the timer is currently running the previous list will remain active
     * until the user selects another task.
     */
    public void show_task_list (TaskList task_list) {
        if (task_list == _shown_list) {
            return;
        }

        foreach (Gtk.Widget widget in activity_stack.get_children ()) {
            activity_stack.remove (widget);
        }
        if (_shown_list != null && _shown_list != _active_list) {
            _shown_list.task_selected.disconnect (switch_to_list_with_task);
            _shown_list.unload ();
        }

        _shown_list = task_list;
        if (task_list != _active_list) {
            _shown_list.load ();
            _shown_list.task_selected.connect (switch_to_list_with_task);
        }
        add_widgets ();
        this.show_all ();
    }

    public void switch_to_list_with_task (TaskList list, TodoTask task) {
        if (_active_list != list) {
            if (_active_list != null) {
                if (_active_list != _shown_list) {
                    _active_list.task_selected.disconnect (switch_to_list_with_task);
                }
                _active_list.timer_values_changed.disconnect (update_timer_values);
                _active_list.unload ();
            }
            _active_list = list;
            _active_list.timer_values_changed.connect (update_timer_values);
            update_timer_values (
                _active_list.get_schedule (),
                _active_list.get_reminder_time ()
            );
        }
        task_timer.active_task = task;
        show_timer ();
    }

    public void remove_active_task_list () {
        if (_active_list == null) {
            return;
        }
        if (task_timer.running) {
            task_timer.stop ();
        }
        _active_list.task_selected.disconnect (switch_to_list_with_task);
        _active_list.timer_values_changed.disconnect (update_timer_values);
        _active_list = null;
    }

    /**
     * Restores this to its state from before set_task_list was called.
     */
    public void remove_task_list () {
        task_timer.stop ();
        bool single_list = _shown_list == _active_list;
        if (_shown_list != null) {
            _shown_list.task_selected.disconnect (switch_to_list_with_task);
            _shown_list.unload ();
        }
        if (_active_list != null) {
            if (!single_list) {
                _active_list.task_selected.disconnect (switch_to_list_with_task);
                _active_list.unload ();
            }
            _active_list.timer_values_changed.disconnect (update_timer_values);
        }

        foreach (Gtk.Widget widget in activity_stack.get_children ()) {
            activity_stack.remove (widget);
        }

        disconnect_first_page_signals ();
        first_page = null;
        last_page = null;

        task_timer.reset ();

        _shown_list = null;
        _active_list = null;
    }

    /**
     * Returns true if this widget has been properly initialized.
     */
    public bool ready {
        get {
            return (_shown_list != null);
        }
    }
}
