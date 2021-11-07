/* Copyright 2014-2021 Go For It! developers
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
class GOFI.TXT.TxtListInstance : Object {
    private TaskManager task_manager;
    private TaskListWidget ready_list;
    private TaskListWidget waiting_list;
    private Gtk.Grid todo_list;
    private TaskListWidget done_list;
    private Gtk.Entry add_new_txt;

    private Gtk.ScrolledWindow done_scroll;
    private Gtk.ScrolledWindow todo_scroll;

    private Gtk.Box menu_box;

    public signal void timer_task_chosen (TxtTask task);

    public TxtListInstance (ListSettings list_settings) {
        task_manager = new TaskManager (list_settings);

        initialize_widgets ();

        /* Action and Signal Handling */
        ready_list.selection_changed.connect (on_timer_task_chosen);
    }

    ~TxtListInstance () {
        task_manager.prepare_free ();
        task_manager.save_scheduled_lists ();
    }

    public void on_timer_task_chosen (TxtTask? task) {
        if (task == null) {
            return;
        }
        timer_task_chosen (task);
    }

    private void initialize_todo_list_widgets () {
        ready_list = new TaskListWidget (this.task_manager.todo_store);
        waiting_list = new TaskListWidget (this.task_manager.waiting_store);

        add_new_txt = new Gtk.Entry ();
        add_new_txt.hexpand = true;
        add_new_txt.placeholder_text = _("Add new task") + "…";
        add_new_txt.margin = 5;

        add_new_txt.set_icon_from_icon_name (
            Gtk.EntryIconPosition.SECONDARY, "list-add-symbolic");

        /* Action and Signal Handling */
        // Handle clicks on the icon
        add_new_txt.icon_press.connect (on_add_new_txt_icon_press);
        // Handle "activate" signals (Enter Key presses)
        add_new_txt.activate.connect (on_entry_activate);

        var sc = kbsettings.get_shortcut (KeyBindingSettings.SCK_ADD_NEW);
        add_new_txt.tooltip_markup = sc.get_accel_markup (_("Add new task"));

        var waiting_list_revealer = new Gtk.Revealer ();
        waiting_list_revealer.vexpand = false;

        var waiting_list_expander = new Gtk.Expander (_("Upcoming"));
        waiting_list_revealer.add (waiting_list_expander);
        waiting_list_expander.add (waiting_list);

        todo_list = new Gtk.Grid ();
        todo_list.orientation = Gtk.Orientation.VERTICAL;
        todo_list.add (add_new_txt);
        todo_list.add (ready_list);
        todo_list.add (waiting_list_revealer);

        todo_scroll = new Gtk.ScrolledWindow (null, null);
        todo_scroll.add (todo_list);

        ready_list.list_adjustment = todo_scroll.vadjustment;
        waiting_list.list_adjustment = todo_scroll.vadjustment;

        task_manager.notify["waiting-tasks-available"].connect (() => {
            // FIXME: check why this doesn't work
            stdout.printf ("waiting-tasks-available\n");
            waiting_list_revealer.reveal_child = task_manager.waiting_tasks_available;
        });
        waiting_list_revealer.reveal_child = task_manager.waiting_tasks_available;
    }

    private void initialize_done_list_widgets () {
        done_list = new TaskListWidget (this.task_manager.done_store);

        done_scroll = new Gtk.ScrolledWindow (null, null);
        done_scroll.add (done_list);

        done_list.list_adjustment = done_scroll.vadjustment;
    }

    private void initialize_menu () {
        var clear_done_button = new Gtk.ModelButton ();
        clear_done_button.text = _("Clear Done List");
        clear_done_button.clicked.connect (clear_done_list);

        var sort_tasks_button = new Gtk.ModelButton ();
        var sort_tasks_text = _("Sort Tasks");
#if USE_GRANITE
        sort_tasks_button.get_child ().destroy ();
        var sc = kbsettings.get_shortcut (KeyBindingSettings.SCK_SORT);
        if (sc.is_valid) {
            sort_tasks_button.add (new Granite.AccelLabel (sort_tasks_text, sc.to_string ()));
        } else {
            sort_tasks_button.add (new Granite.AccelLabel (sort_tasks_text));
        }
#else
        // Gtk.AccelLabel is too buggy to use
        sort_tasks_button.text = sort_tasks_text;
#endif
        sort_tasks_button.clicked.connect (sort_tasks);

        menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        menu_box.add (sort_tasks_button);
        menu_box.add (clear_done_button);
        menu_box.show_all ();
    }

    private void initialize_widgets () {
        initialize_todo_list_widgets ();
        initialize_done_list_widgets ();
        initialize_menu ();
    }

    public unowned Gtk.Widget get_todo_list_widget () {
        return todo_scroll;
    }

    public unowned Gtk.Widget get_done_list_widget () {
        return done_scroll;
    }

    public unowned Gtk.Widget get_menu () {
        return menu_box;
    }

    /**
     * Returns the next task relative to relative_to.
     */
    public TxtTask? get_next (TxtTask? relative_to) {
        return task_manager.get_next (relative_to);
    }

    /**
     * Returns the previous task relative to relative_to.
     */
    public TxtTask? get_prev (TxtTask? relative_to) {
        return task_manager.get_prev (relative_to);
    }

    public void entry_focus () {
        add_new_txt.grab_focus ();
    }

    public void clear_done_list () {
        task_manager.clear_done_store ();
    }

    public void sort_tasks () {
        task_manager.sort_tasks ();
    }

    private void on_add_new_txt_icon_press (Gtk.EntryIconPosition pos, Gdk.Event event) {
        if (pos == Gtk.EntryIconPosition.SECONDARY) {
            on_entry_activate ();
        }
    }

    private void on_entry_activate () {
        task_manager.add_new_task (add_new_txt.text);
        add_new_txt.text = "";
        // placeholder_text = PLACEHOLDER_TEXT_FINISHED;
        // placeholder.label = PLACEHOLDER_TEXT_FINISHED;
    }

    /**
     * Called when the user has finished working on this task.
     */
    public void mark_done (TxtTask task) {
        task_manager.mark_done (task);
    }
}

class GOFI.TXT.TxtList : GOFI.TaskList, Object {
    private TxtListInstance instance;

    public ListSettings list_settings {
        public get;
        private set;
    }

    public TodoListInfo list_info {
        public get {
            return list_settings;
        }
    }

    public TxtList (ListSettings list_settings) {
        this.list_settings = list_settings;

        list_settings.notify.connect (on_list_settings_notify);
    }

    private void on_list_settings_notify (ParamSpec pspec) {
        switch (pspec.get_name ()) {
            case "schedule":
                signal_timer_values ();
                break;
            case "reminder_time":
                signal_timer_values ();
                break;
            default:
                break;
        }
    }

    private void signal_timer_values () {
        timer_values_changed (
            list_settings.schedule,
            list_settings.reminder_time
        );
    }

    public File? get_log_file () {
        var uri = list_settings.activity_log_uri;
        if (uri == null || uri == "") {
            return null;
        }
        var file = File.new_for_uri (uri);
        return file;
    }

    /**
     * Returns the next task relative to relative_to.
     */
    public TodoTask? get_next (TodoTask? relative_to) {
        assert (instance != null);
        return instance.get_next ((TxtTask) relative_to);
    }

    /**
     * Returns the previous task relative to relative_to.
     */
    public TodoTask? get_prev (TodoTask? relative_to) {
        assert (instance != null);
        return instance.get_prev ((TxtTask) relative_to);
    }

    /**
     * Called when the user has finished working on this task.
     */
    public void mark_done (TodoTask task) {
        assert (instance != null);
        instance.mark_done ((TxtTask) task);
    }

    /**
     * Tasks that the user should currently work on
     */
    public unowned Gtk.Widget get_primary_page (out string? page_name) {
        assert (instance != null);
        page_name = null;
        return instance.get_todo_list_widget ();
    }

    /**
     * Can be future recurring tasks or tasks that are already done
     */
    public unowned Gtk.Widget get_secondary_page (out string? page_name) {
        assert (instance != null);
        page_name = null;
        return instance.get_done_list_widget ();
    }

    public unowned Gtk.Widget? get_menu () {
        assert (instance != null);
        return instance.get_menu ();
    }

    /**
     * Returns the schedule of task and break times specific to this list.
     */
    public TimerSchedule? get_schedule () {
        return list_settings.schedule;
    }

    /**
     * Returns the duration (in seconds) of the break the user should take
     * before resuming work on the task.
     * If no value is configured -1 should be returned.
     */
    public int get_reminder_time () {
        return list_settings.reminder_time;
    }

    public void add_task_shortcut () {
        assert (instance != null);
        instance.entry_focus ();
    }

    /**
     * Called when this todo.txt list has been selected by the user.
     * This function should be used to initialize the widgets and other objects.
     */
    public void load () {
        instance = new TxtListInstance (list_settings);
        instance.timer_task_chosen.connect (on_task_chosen);
    }

    private void on_task_chosen (TxtTask task) {
        task_selected (task);
    }

    /**
     * This function is called when this list is no longer in use but may be
     * loaded again in the future.
     * Widgets and other objects should be freed to preserve resources.
     */
    public void unload () {
        instance.timer_task_chosen.disconnect (on_task_chosen);
        instance = null;
    }
}
