/* Copyright 2018-2019 GoForIt! developers
*
* This file is part of GoForIt!.
*
* GoForIt! is free software: you can redistribute it
* and/or modify it under the terms of version 3 of the
* GNU General Public License as published by the Free Software Foundation.
*
* GoForIt! is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with GoForIt!. If not, see http://www.gnu.org/licenses/.
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

    private Gtk.Grid first_page_layout;
    private Gtk.Widget first_page;
    private TimerView timer_view;
    private TimerBar timer_bar;
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
        switch_active_task_list ();
        if (_shown_list == null) {
            return;
        }
        var next = _active_list.get_next ();

        if (next != null) {
            _active_list.active_task = next;
        }
    }

    [Signal (action = true)]
    public virtual signal void switch_to_prev () {
        switch_active_task_list ();
        if (_shown_list == null) {
            return;
        }
        var prev = _active_list.get_prev ();

        if (prev != null) {
            _active_list.active_task = prev;
        }
    }

    public void propagate_filter_action () {
        var visible_child = activity_stack.get_visible_child ();
        unowned ObjectClass? oc = null;
        if (visible_child == first_page_layout) {
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
        if (visible_child == first_page_layout) {
            var selected_task = _shown_list.selected_task;
            if (selected_task != null) {
                _shown_list.mark_done (selected_task);
            }
        } else if (visible_child == timer_view) {
            bool was_running = task_timer.running;
            task_timer.stop ();
            on_task_done ();
            // Resume break, only keep stopped when a task is active
            if (_active_list.active_task != null &&
                (task_timer.break_active ||
                 !settings.reset_timer_on_task_switch) &&
                was_running) {
                task_timer.start ();
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
        timer_view = new TimerView (task_timer);
        timer_bar = new TimerBar (task_timer);
        var activity_label = new Gtk.Label (_("Lists"));
        activity_label.get_style_context ().add_class ("title");

        // Activity Stack + Switcher
        activity_stack.set_transition_type (
            Gtk.StackTransitionType.SLIDE_UP_DOWN
        );
        timer_view.done_btn_clicked.connect (on_task_done);

        this.add (activity_stack);

        timer_bar.timer_page_btn_clicked.connect (() => {
            activity_stack.visible_child_name = "timer";
        });
        timer_view.close_btn_clicked.connect (() => {
            activity_stack.visible_child_name = "primary";
        });
    }

    public void action_add_task () {
        activity_stack.visible_child_name = "primary";
        _shown_list.add_task_shortcut ();
    }

    public bool switch_page_left () {
        switch (activity_stack.visible_child_name) {
            case "timer":
                activity_stack.visible_child_name = "primary";
                return false;
            case "secondary":
                activity_stack.visible_child_name = "timer";
                return false;
            default:
                return true;
        }
    }

    public bool switch_page_right () {
        switch (activity_stack.visible_child_name) {
            case "primary":
                activity_stack.visible_child_name = "timer";
                return false;
            case "timer":
                activity_stack.visible_child_name = "secondary";
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

        disconnect_first_page_signals ();

        /* Instantiation of the Widgets */
        first_page = _shown_list.get_primary_page (out first_page_name);
        first_page_layout = new Gtk.Grid ();
        first_page_layout.orientation = Gtk.Orientation.VERTICAL;
        first_page_layout.add (first_page);
        first_page_layout.add (timer_bar);

        if (first_page_name == null) {
           first_page_name = _("To-Do");
        }

        // Add widgets to the activity stack
        activity_stack.add_titled (first_page_layout, "primary", first_page_name);
        activity_stack.add_titled (timer_view, "timer", _("Timer"));

        if (task_timer.running) {
            // Otherwise no task will be displayed in the timer view
            task_timer.update_active_task ();

            // Otherwise it won't switch
            timer_view.show ();

            activity_stack.visible_child_name = "timer";
            activity_stack.visible_child = timer_view;
        }
        else {
            first_page.show ();

            activity_stack.visible_child_name = "primary";
            activity_stack.visible_child = first_page_layout;
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

    /**
     * Updates this to display the new TaskList and use this list for the timer.
     */
    public void set_task_list (TaskList task_list) {
        if (this._active_list == null) {
            this._active_list = task_list;
        } else if (!task_timer.running) {
            remove_task_list ();
            this._active_list = task_list;
        }
        this._shown_list = task_list;
        this._shown_list.load ();
        _shown_list.notify["active-task"].connect (on_active_task_changed);
        _shown_list.notify["selected-task"].connect (on_selected_task_changed);
        _shown_list.timer_values_changed.connect (update_timer_values);
        update_timer_values (
            _shown_list.get_schedule (),
            _shown_list.get_reminder_time ()
        );
        add_widgets ();
        this.show_all ();
        on_selected_task_changed ();
    }

    private void update_timer_values (Schedule? sched, int reminder_t) {
        if (sched != null && !sched.valid) {
            sched = null;
        }
        task_timer.schedule = sched;
        task_timer.reminder_time = reminder_t;
    }

    private void on_task_done () {
        _active_list.mark_done (task_timer.active_task);
    }

    private void on_active_task_changed () {
        task_timer.active_task = _active_list.active_task;
    }

    private void on_selected_task_changed () {
        // Don't change task, while timer is running
        if (!task_timer.running) {
            if (_shown_list != _active_list) {
                switch_active_task_list ();
            }
            _shown_list.active_task = _shown_list.selected_task;
        }
    }

    /**
     * If the first page receives focus, check if the selected task needs to be
     * refreshed
     */
    private void on_first_page_focus (Gtk.Widget? child) {
        if (child != null && shown_list != active_list) {
            // Task may be stale, lets refresh the selected task if necessary
            on_selected_task_changed ();
        }
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

    public void show_timer () {
        activity_stack.visible_child = timer_view;
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
        if (_shown_list != null) {
            _shown_list.notify["selected-task"].disconnect (on_selected_task_changed);
        }
        foreach (Gtk.Widget widget in activity_stack.get_children ()) {
            activity_stack.remove (widget);
        }
        first_page = null;
        if (first_page_layout != null) {
            first_page_layout.remove (timer_bar);
        }
        first_page_layout = null;
        last_page = null;
        if (_shown_list != _active_list) {
            _shown_list.unload ();
        }
        _shown_list = task_list;
        if (task_list != _active_list) {
            _shown_list.load ();
        }
        add_widgets ();
        _shown_list.notify["selected-task"].connect (on_selected_task_changed);

        if (!task_timer.running) {
            switch_active_task_list ();
        }
        this.show_all ();
    }

    /**
     * This function is used to switch active_list to shown_list which happens
     * if the list shown has been changed and the user switches to the next
     * task or if the timer was not running during the change of shown lists.
     */
    public void switch_active_task_list () {
        if (_active_list == _shown_list) {
            return;
        }
        task_timer.stop ();
        if (_active_list != null) {
            _active_list.unload ();
            _active_list.notify["active-task"].disconnect (on_active_task_changed);
            _active_list.timer_values_changed.disconnect (update_timer_values);
        }

        _active_list = _shown_list;

        _active_list.notify["active-task"].connect (on_active_task_changed);
        _active_list.timer_values_changed.connect (update_timer_values);
        update_timer_values (
            _active_list.get_schedule (),
            _active_list.get_reminder_time ()
        );
        on_selected_task_changed ();
    }

    /**
     * Restores this to its state from before set_task_list was called.
     */
    public void remove_task_list () {
        task_timer.stop ();
        if (_shown_list != null) {
            _shown_list.unload ();
            if (_shown_list != _active_list) {
                _active_list.unload ();
            }
            _active_list.notify["active-task"].disconnect (on_active_task_changed);
            _shown_list.notify["selected-task"].disconnect (on_selected_task_changed);
            _active_list.timer_values_changed.disconnect (update_timer_values);
        }
        foreach (Gtk.Widget widget in activity_stack.get_children ()) {
            activity_stack.remove (widget);
        }

        disconnect_first_page_signals ();
        first_page = null;
        if (first_page_layout != null) {
            first_page_layout.remove (timer_bar);
        }
        first_page_layout = null;
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
            return (_active_list != null);
        }
    }
}
