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

using GOFI.TXT.TxtUtils;

/**
 * This class is responsible for loading, saving and managing the user's tasks.
 * Therefore it offers methods for interacting with the set of tasks in all
 * lists. Editing specific tasks (e.g. removing, renaming) is to be done
 * by addressing the corresponding TaskStore instance.
 */
class GOFI.TXT.TaskManager : Object {
    private ListSettings lsettings;
    // The user's todo.txt related files
    private File todo_txt;
    private File done_txt;
    private File waiting_txt;
    public TaskStore todo_store;
    public TaskStore done_store;
    public TaskStore waiting_store;
    private bool read_only;
    private bool io_failed;

    // refreshing
    private bool refresh_scheduled;
    private FileWatcher todo_watcher;
    private FileWatcher done_watcher;
    private FileWatcher waiting_watcher;

    enum SaveStatus {
        NONE_SCHEDULED,
        LARGE_DELAY,
        SMALL_DELAY
    }

    private SaveStatus todo_save_status;
    private SaveStatus done_save_status;
    private SaveStatus waiting_save_status;

    private uint todo_save_timeout_id;
    private uint done_save_timeout_id;
    private uint waiting_save_timeout_id;

    const int LOW_PRIO_SAVE_DELAY = 30000;
    const int HIGH_PRIO_SAVE_DELAY = 100;

    const string ERROR_IMPLICATIONS = _("%s won't save or load from the current todo.txt folder until it is either restarted or another location is chosen."); // vala-lint=line-length
    string read_error_message = _("Couldn't read the todo.txt file (%s):") + "\n\n%s\n\n";
    string write_error_message = _("Couldn't save the to-do list (%s):") + "\n\n%s\n\n";

    public bool waiting_tasks_available {
        get {
            return waiting_store.get_n_items () > 0;
        }
    }

    public signal void refreshing ();
    public signal void refreshed ();

    public TaskManager (ListSettings lsettings) {
        this.lsettings = lsettings;

        // Initialize TaskStores
        todo_store = new TaskStore (false);
        waiting_store = new TaskStore (false);
        done_store = new TaskStore (true);

        refresh_scheduled = false;
        todo_save_status = SaveStatus.NONE_SCHEDULED;
        done_save_status = SaveStatus.NONE_SCHEDULED;
        waiting_save_status = SaveStatus.NONE_SCHEDULED;

        load_task_stores ();
        connect_store_signals ();
        post_load_task_schedule ();

        GLib.Timeout.add (300000, move_waiting_tasks);
        GLib.Timeout.add (300000, reschedule_overdue_tasks);

        /* Signal processing */
        waiting_store.items_changed.connect ((pos, removed, added) => {
            if (removed != added) {
                this.notify["waiting-tasks-available"];
            }
        });

        // these properties sometimes get updated multiple times without
        // actually changing, which could cause 1-6 extra reloads
        lsettings.notify["todo-uri"].connect (on_todo_uri_changed);
        lsettings.notify["waiting-uri"].connect (on_waiting_uri_changed);
        lsettings.notify["done-uri"].connect (on_done_uri_changed);
    }

    public void prepare_free () {
        lsettings.notify["todo-uri"].disconnect (on_todo_uri_changed);
        lsettings.notify["waiting-uri"].disconnect (on_waiting_uri_changed);
        lsettings.notify["done-uri"].disconnect (on_done_uri_changed);
    }

    private void on_todo_uri_changed () {
        if (lsettings.todo_uri != todo_txt.get_uri ()) {
            load_tasks_stores_and_reschedule ();
        }
    }
    private void on_waiting_uri_changed () {
        if (lsettings.waiting_uri != waiting_txt.get_uri ()) {
            load_tasks_stores_and_reschedule ();
        }
    }
    private void on_done_uri_changed () {
        if (lsettings.done_uri != done_txt.get_uri ()) {
            load_tasks_stores_and_reschedule ();
        }
    }

    public TxtTask? get_next (TxtTask? relative_to) {
        int position = 0;

        if (relative_to != null) {
            position = (int) todo_store.get_task_position (relative_to) + 1;
        }
        return todo_store.get_task_wrap (position);
    }

    public TxtTask? get_prev (TxtTask? relative_to) {
        int position = -1;

        if (relative_to != null) {
            position = (int) todo_store.get_task_position (relative_to) - 1;
        }
        return todo_store.get_task_wrap (position);
    }

    public void mark_done (TxtTask task) {
        task.done = true;
    }

    /**
     * To be called when adding a new (unfinished) task.
     */
    public void add_new_task (string task) {
        string _task = task.strip ();
        if (_task != "") {
            var todo_task = new TxtTask.from_simple_txt (_task, false);
            if (!todo_task.valid) {
                return;
            }
            if (!lsettings.add_creation_dates) {
                todo_task.creation_date = null;
            }
            if (settings.new_tasks_on_top) {
                todo_store.prepend_task (todo_task);
            } else {
                todo_store.add_task (todo_task);
            }
        }
    }

    /**
     * Transfers a task from one TaskStore to another.
     */
    private void transfer_task (
        TxtTask task, TaskStore source, TaskStore destination
    ) {
        source.remove_task (task);
        destination.add_task (task);
    }

    /**
     * Deletes all task on the "Done" list
     */
    public void clear_done_store () {
        done_store.clear ();
    }

    public void sort_tasks () {
        todo_store.sort ();
        done_store.sort ();
    }

    /**
     * Reloads all tasks.
     */
    public void refresh () {
        stdout.printf ("Refreshing\n");
        refreshing ();
        load_tasks ();
        post_load_task_schedule ();
        refreshed ();
    }

    private bool auto_refresh () {
        // Have the writes stopped yet?
        if (todo_watcher.being_updated) {
            return true;
        }
        if ((done_watcher != null && done_watcher.being_updated) ||
            (waiting_watcher != null && waiting_watcher.being_updated)
        ) {
            return true;
        }

        refresh ();

        refresh_scheduled = false;

        return false;
    }

    // I kept messing up comparisons
    private static inline bool date_before (GOFI.Date a, DateTime b) {
        return (a.dt_compare_date (b) < 0);
    }
    private static inline bool date_after (GOFI.Date a, DateTime b) {
        return (a.dt_compare_date (b) > 0);
    }

    private bool move_waiting_tasks () {
        if (!refresh_scheduled) {
            var now = new DateTime.now_local ();
            uint n_items = waiting_store.get_n_items ();
            TxtTask[] to_move = {};
            for (uint i = 0; i < n_items; i++) {
                unowned TxtTask task = (TxtTask) waiting_store.get_item (i);
                if (!date_after (task.threshold_date, now)) {
                    to_move += task;
                }
            }
            foreach (TxtTask task in to_move) {
                transfer_task (task, waiting_store, todo_store);
            }
        }

        return Source.CONTINUE;
    }

    private bool reschedule_overdue_tasks () {
        if (!refresh_scheduled) {
            var now = new DateTime.now_local ();
            uint n_items = todo_store.get_n_items ();
            for (uint i = 0; i < n_items; i++) {
                unowned TxtTask task = (TxtTask) todo_store.get_item (i);
                task_auto_reschedule (now, task);
            }
        }

        return Source.CONTINUE;
    }

    private void task_auto_reschedule (DateTime now, TxtTask task) {
        if (task.recur_mode != RecurrenceMode.PERIODICALLY_AUTO_RESCHEDULE) {
            return;
        }
        Date? task_due = task.due_date;
        if (task_due != null && date_before (task_due, now)) {
            var due_dt = task_due.dt;
            unowned SimpleRecurrence recur = task.recur;
            if (recur == null) {
                critical ("Invalid TxtTask state for task %p: recurrence rule is missing!", task);
                return;
            }
            var iter = new SimpleRecurrenceIterator (recur, due_dt);
            var new_due = iter.next_skip_dates (now);
            if (new_due != null) {
                task.due_date = new Date (new_due);
                unowned Date? threshold_date = task.threshold_date;
                if (threshold_date != null) {
                    task.threshold_date = new Date(threshold_date.dt.add (
                        new_due.difference (due_dt)
                    ));
                }
            }
        }
    }

    private void connect_store_signals () {
        // Save data, as soon as something has changed
        todo_store.task_data_changed.connect (schedule_todo_task_save_high_prio);
        waiting_store.task_data_changed.connect (schedule_waiting_task_save_high_prio);
        done_store.task_data_changed.connect (schedule_done_task_save_high_prio);
        // The timer values get updated often and other apps probably don't need this information
        todo_store.timer_value_changed.connect (schedule_todo_task_save_low_prio);
        waiting_store.timer_value_changed.connect (schedule_waiting_task_save_low_prio);

        // Move task from one list to another, if done or undone
        todo_store.task_done_changed.connect (task_done_handler);
        waiting_store.task_done_changed.connect (task_done_handler);
        done_store.task_done_changed.connect (task_done_handler);

        todo_store.task_threshold_date_changed.connect (ready_task_threshold_date_changed);
        waiting_store.task_threshold_date_changed.connect (waiting_task_threshold_date_changed);

        // Remove tasks that are no longer valid (user has changed description to "")
        todo_store.task_became_invalid.connect (remove_invalid);
        waiting_store.task_became_invalid.connect (remove_invalid);
        done_store.task_became_invalid.connect (remove_invalid);
    }

    private void ready_task_threshold_date_changed (TxtTask task) {
        var now = new DateTime.now_local ();
        if (date_after (task.threshold_date, now)) {
            transfer_task (task, todo_store, waiting_store);
        }
    }

    private void waiting_task_threshold_date_changed (TxtTask task) {
        var now = new DateTime.now_local ();
        if (!date_after (task.threshold_date, now)) {
            transfer_task (task, waiting_store, todo_store);
        }
    }

    private void load_task_stores () {
        todo_txt = File.new_for_uri (lsettings.todo_uri);
        done_txt = File.new_for_uri (lsettings.done_uri);
        waiting_txt = File.new_for_uri (lsettings.waiting_uri);

        if (todo_txt.query_exists ()) {
            lsettings.add_default_todos = false;
        }

        load_tasks ();

        if (!io_failed) {
            watch_files ();
        }
    }

    private void watch_files () {
        todo_watcher = new FileWatcher (todo_txt);
        todo_watcher.changed.connect (on_file_changed);

        if (todo_txt.equal (waiting_txt)) {
            waiting_watcher = null;
        } else {
            waiting_watcher = new FileWatcher (waiting_txt);
            waiting_watcher.changed.connect (on_file_changed);
        }
        if (todo_txt.equal (done_txt) || waiting_txt.equal (done_txt)) {
            done_watcher = null;
        } else {
            done_watcher = new FileWatcher (done_txt);
            done_watcher.changed.connect (on_file_changed);
        }
    }

    private void on_file_changed () {
        if (!refresh_scheduled) {
            refresh_scheduled = true;

            // Reload after 0.5 seconds so we can be relatively sure, that the
            // other application has finished writing
            GLib.Timeout.add (
                500, auto_refresh, GLib.Priority.DEFAULT_IDLE
            );
        }
    }

    /**
     * Removes recurrence information from task and schedules new task if
     * necessary
     */
    private void task_schedule_new (TxtTask task, DateTime? dt = null) {
        var recur_mode = task.recur_mode;

        if (recur_mode <= RecurrenceMode.NO_RECURRENCE) {
            return;
        }
        unowned SimpleRecurrence recur = task.recur;
        if (recur == null) {
            critical ("Invalid TxtTask state for task %p: recurrence rule is missing!", task);
            return;
        }
        var new_task = new TxtTask.from_template_task (task);
        task.recur_mode = RecurrenceMode.NO_RECURRENCE;
        task.recur = null;
        var task_due = new_task.due_date;
        if (task_due == null) {
            warning ("Encountered recurring todo.txt task without due date: %s", task.to_txt (false));
            task_due = new Date (new GLib.DateTime.now_local ());
        }
        DateTime? new_due_dt;
        DateTime now_dt;
        if (dt == null) {
            now_dt = new DateTime.now_local ();
        } else {
            now_dt = dt;
        }
        switch (recur_mode) {
            case RecurrenceMode.PERIODICALLY_AUTO_RESCHEDULE:
            case RecurrenceMode.PERIODICALLY_SKIP_OLD:
                var iter = new SimpleRecurrenceIterator (recur, task_due.dt);
                new_due_dt = iter.next_skip_dates (now_dt);
                break;
            case RecurrenceMode.ON_COMPLETION:
                unowned DateTime completion_date;
                if (task.completion_date != null) {
                    completion_date = task.completion_date.dt;
                } else {
                    completion_date = now_dt;
                }
                var iter = new SimpleRecurrenceIterator (recur, completion_date);
                new_due_dt = iter.next ();
                break;
            default:
                var iter = new SimpleRecurrenceIterator (recur, task_due.dt);
                new_due_dt = iter.next ();
                break;
        }
        if (new_due_dt == null) {
            return;
        }
        if (lsettings.add_creation_dates) {
            new_task.creation_date = new Date (new GLib.DateTime.now_local ());
        }
        var new_due_date = new Date (new_due_dt);
        new_task.due_date = new_due_date;
        var threshold_date = task.threshold_date;
        if (task.threshold_date != null) {
            var threshold_dt = threshold_date.dt.add_days (
                task_due.days_between (new_due_date)
            );
            threshold_date = new Date (threshold_dt);
            new_task.threshold_date = threshold_date;
            if (date_after (threshold_date, now_dt)) {
                waiting_store.add_task (new_task);
                return;
            }
        }
        todo_store.add_task (new_task);
    }

    private void task_done_handler (TaskStore source, TxtTask task) {
        if (source == todo_store) {
            transfer_task (task, todo_store, done_store);
            task_schedule_new (task);
        } else if (source == done_store) {
            transfer_task (task, done_store, todo_store);
        } else if (source == waiting_store) {
            transfer_task (task, waiting_store, done_store);
            task_schedule_new (task);
        }
    }

    private void remove_invalid (TaskStore store, TxtTask task) {
        store.remove_task (task);
        save_store (store);
    }

    private void load_tasks () {
        // read_only flag, so that "clear ()" does not delete the files' content
        read_only = true;

        GLib.Array<TxtTask> tasks_arr = new GLib.Array<TxtTask> ();
        List<TxtTask> in_use = new List<TxtTask> ();

        unowned File active_file = todo_txt;
        try {
            read_task_file (todo_txt, false, tasks_arr);

            if (!todo_txt.equal (waiting_txt)) {
                active_file = waiting_txt;
                read_task_file (waiting_txt, false, tasks_arr);
            }
            if (!(todo_txt.equal (done_txt) || waiting_txt.equal (done_txt))) {
                active_file = done_txt;
                read_task_file (done_txt, true, tasks_arr);
            }
        } catch (Error e) {
            io_failed = true;
            var error_message =
                read_error_message.printf (active_file.get_uri (), e.message) +
                ERROR_IMPLICATIONS.printf (APP_NAME);
            warning (error_message);
            show_error_dialog (error_message);

            return;
        }

        list_in_use_and_clear (todo_store, ref in_use);
        list_in_use_and_clear (waiting_store, ref in_use);
        done_store.clear ();

        combine_lists (tasks_arr.data, (owned) in_use, lsettings.log_timer_in_txt);

        var now_time = new DateTime.now_local ();

        foreach (var task in tasks_arr.data) {
            if (task.done) {
                done_store.add_task (task);
            } else {
                task_auto_reschedule (now_time, task);
                if (task.threshold_date != null &&
                    date_after (task.threshold_date, now_time)
                ) {
                    waiting_store.add_task (task);
                } else {
                    todo_store.add_task (task);
                }
            }
        }

        if (settings.add_default_todos && lsettings.add_default_todos) {
            add_default_todos ();
        }

        read_only = false;
    }

    private void list_in_use_and_clear (TaskStore store, ref List<TxtTask> in_use) {
        TxtTask task;
        for (uint i = 0; (task = store.get_task (i)) != null; i++) {
            if ((task.status & TaskStatus.TIMER_SELECTED) != 0) {
                in_use.prepend (task);
            } else {
                task.invalidate ();
            }
        }
        store.clear ();
    }

    private void post_load_task_schedule () {
        var now = new DateTime.now_local ();
        uint n_items = done_store.get_n_items ();
        for (uint i = 0; i < n_items; i++) {
            unowned TxtTask task = done_store.get_task (i);
            task_schedule_new (task, now);
        }
    }

    private void load_tasks_stores_and_reschedule () {
        load_task_stores ();
        post_load_task_schedule ();
    }

    private void add_default_todos () {
        var default_todos = get_default_todos ();
        for (int i = 0; i < default_todos.length; i++) {
            todo_store.add_task (new TxtTask (default_todos[i], false));
        }
        lsettings.add_default_todos = false;
        settings.add_default_todos = false;
    }

    /**
     * Saves lists for which a timeout job exists
     */
    public void save_scheduled_lists () {
        if (todo_save_status != SaveStatus.NONE_SCHEDULED) {
            Source.remove (todo_save_timeout_id);
            save_todo_tasks ();
        }
        if (waiting_save_status != SaveStatus.NONE_SCHEDULED) {
            Source.remove (waiting_save_timeout_id);
            save_waiting_tasks ();
        }
        if (done_save_status != SaveStatus.NONE_SCHEDULED) {
            Source.remove (done_save_timeout_id);
            save_done_tasks ();
        }
    }

    /**
     * Adds a timeout job to save the todo.txt list.
     * A timeout is used to reduce the number of times the list is saved.
     * It may be useful to increase the interval value to reduce the amount of
     * stutter when dealing with very large lists on weak machines.
     * (Move the moment of saving to a time where the user isn't actively
     * using the app)
     * But we would need to check that the user isn't currently performing a
     * drag and drop action as saves at such a moment would be the most
     * noticable.
     */
    private void schedule_todo_task_save (bool high_priority = true) {
        if (todo_save_status == SaveStatus.SMALL_DELAY || read_only) {
            return;
        }
        uint interval = HIGH_PRIO_SAVE_DELAY;
        if (!high_priority) {
            interval = LOW_PRIO_SAVE_DELAY;
        }
        if (todo_save_status == SaveStatus.LARGE_DELAY && high_priority) {
            // Reschedule to happen sooner (probably)
            reschedule_source (todo_save_timeout_id, interval);
        } else {
            todo_save_timeout_id = GLib.Timeout.add (
                interval, save_todo_tasks, GLib.Priority.DEFAULT_IDLE
            );
        }
        if (high_priority) {
            todo_save_status = SaveStatus.SMALL_DELAY;
        } else {
            todo_save_status = SaveStatus.LARGE_DELAY;
        }
    }
    private void schedule_todo_task_save_high_prio () {
        schedule_todo_task_save (true);
    }
    private void schedule_todo_task_save_low_prio () {
        schedule_todo_task_save (false);
    }

    private static inline void reschedule_source (uint id, uint interval) {
        MainContext.default ().find_source_by_id (id).set_ready_time (
            GLib.get_monotonic_time () + interval * 1000
        );
    }

    private void schedule_waiting_task_save (bool high_priority = true) {
        if (waiting_save_status == SaveStatus.SMALL_DELAY || read_only) {
            return;
        }
        if (todo_txt.equal (waiting_txt)) {
            schedule_todo_task_save (high_priority);
            return;
        }
        uint interval = HIGH_PRIO_SAVE_DELAY;
        if (!high_priority) {
            interval = LOW_PRIO_SAVE_DELAY;
        }
        if (waiting_save_status == SaveStatus.LARGE_DELAY && high_priority) {
            // Reschedule to happen sooner, probably
            reschedule_source (waiting_save_timeout_id, interval);
        } else {
            waiting_save_timeout_id = GLib.Timeout.add (
                interval, save_waiting_tasks, GLib.Priority.DEFAULT_IDLE
            );
        }
        if (high_priority) {
            waiting_save_status = SaveStatus.SMALL_DELAY;
        } else {
            waiting_save_status = SaveStatus.LARGE_DELAY;
        }
    }
    private void schedule_waiting_task_save_high_prio () {
        schedule_waiting_task_save (true);
    }
    private void schedule_waiting_task_save_low_prio () {
        schedule_waiting_task_save (false);
    }

    private void schedule_done_task_save (bool high_priority = true) {
        if (done_save_status == SaveStatus.SMALL_DELAY || read_only) {
            return;
        }
        if (waiting_txt.equal (done_txt)) {
            schedule_waiting_task_save (high_priority);
            return;
        }
        if (todo_txt.equal (done_txt)) {
            schedule_todo_task_save (high_priority);
            return;
        }
        uint interval = HIGH_PRIO_SAVE_DELAY;
        if (!high_priority) {
            interval = LOW_PRIO_SAVE_DELAY;
        }
        if (done_save_status == SaveStatus.LARGE_DELAY && high_priority) {
            // Reschedule to happen sooner, probably
            reschedule_source (done_save_timeout_id, interval);
        } else {
            done_save_timeout_id = GLib.Timeout.add (
                interval, save_done_tasks, GLib.Priority.DEFAULT_IDLE
            );
        }
        if (high_priority) {
            done_save_status = SaveStatus.SMALL_DELAY;
        } else {
            done_save_status = SaveStatus.LARGE_DELAY;
        }
    }
    private void schedule_done_task_save_high_prio () {
        schedule_done_task_save (true);
    }

    private bool save_todo_tasks () {
        if (!read_only) {
            save_store (todo_store);
        }
        todo_save_status = SaveStatus.NONE_SCHEDULED;
        return false;
    }

    private bool save_waiting_tasks () {
        if (!read_only) {
            save_store (waiting_store);
        }
        waiting_save_status = SaveStatus.NONE_SCHEDULED;
        return false;
    }

    private bool save_done_tasks () {
        if (!read_only) {
            save_store (done_store);
        }
        done_save_status = SaveStatus.NONE_SCHEDULED;
        return false;
    }

    private void show_error_dialog (string error_message) {
        var dialog = new Gtk.MessageDialog (
            null, Gtk.DialogFlags.DESTROY_WITH_PARENT, Gtk.MessageType.ERROR,
            Gtk.ButtonsType.OK, error_message
        );
        dialog.response.connect ((response_id) => {
            dialog.destroy ();
        });

        dialog.show ();
    }

    private void save_store (TaskStore store) {
        File todo_file;
        FileWatcher watcher = null;
        TaskStore[] stores = {};

        if (store == todo_store) {
            todo_file = todo_txt;
            watcher = todo_watcher;

            if (todo_txt.equal (waiting_txt)) {
                stores = {todo_store, waiting_store};
            } else {
                stores = {todo_store};
            }
            if (todo_txt.equal (done_txt)) {
                stores += done_store;
            }
        } else if (store == done_store) {
            todo_file = done_txt;
            if (done_txt.equal (todo_txt)) {
                stores = {todo_store};
                watcher = todo_watcher;
            }
            if (done_txt.equal (waiting_txt)) {
                stores += waiting_store;
                if (watcher == null) {
                    watcher = waiting_watcher;
                }
            } else if (watcher == null) {
                watcher = done_watcher;
            }
            stores += done_store;
        } else {
            todo_file = waiting_txt;
            if (waiting_txt.equal (todo_txt)) {
                stores = {todo_store, waiting_store};
                watcher = todo_watcher;
            } else {
                stores = {waiting_store};
                watcher = waiting_watcher;
            }
            if (waiting_txt.equal (done_txt)) {
                stores += done_store;
            }
        }
        watcher.watching = false;
        write_task_file (stores, todo_file);
        watcher.watching = true;
    }

    // Create file with its parent directory if it doesn't currently exist
    private static void ensure_file_exists (File file) throws Error {
        Utils.ensure_file_exists (file, FileCreateFlags.NONE);
    }

    private static string remove_carriage_return (string line) {
        int length = line.length;
        if (length > 0) {
            if (line.get_char (length - 1) == 13) {
                if (length == 1) {
                    return "";
                }
                return line.slice (0, length - 1);
            }
        }

        return line;
    }

    private static TxtTask? string_to_task (string _line, bool done_by_default) {
        string line = remove_carriage_return (_line).strip ();
        if (line == "") {
            return null;
        }
        var task = new TxtTask.from_todo_txt (line, done_by_default);
        if (!task.valid) {
            return null;
        }

        return task;
    }

    /**
     * Parses the contents of a file and appends the parsed tasks to an array.
     */
    private static inline void read_task_file (File file, bool done_by_default, GLib.Array<TxtTask> tasks) throws Error {
        ensure_file_exists (file);
        var stream_in = new DataInputStream (file.read ());
        string line;

        while ((line = stream_in.read_line (null)) != null) {
            TxtTask? task = string_to_task (line, done_by_default);
            if (task != null) {
                tasks.append_val (task);
            }
        }
    }

    /**
     * Replaces tasks in tasks_arr with matching tasks from old.
     * invalidate() is called on tasks in old not appearing in tasks_arr.
     * Tasks are matched using all public properties except "timer_value" and "done".
     * Assumption: lists do not contain duplicate tasks.
     *
     * @param tasks_arr an array containing
     * @param old a list of tasks currently in use by the application
     * @param timer_logged_in_txt if false old tasks will not be assigned new
     * "timer_value"s if this new value is 0.
     */
    private static void combine_lists (TxtTask[] tasks_arr, owned List<TxtTask> old, bool timer_logged_in_txt) {
        var index_list = new List<uint> ();

        for (uint i = 1; i <= tasks_arr.length; i++) {
            index_list.prepend (tasks_arr.length - i);
        }

        index_list.sort_with_data ((a, b) => tasks_arr[a].cmp (tasks_arr[b]));
        old.sort ((a, b) => a.cmp (b));

        unowned List<uint> arr_index_link = index_list;
        unowned List<TxtTask> old_tasks_link = old;

        while (arr_index_link != null && old_tasks_link != null) {
            while (arr_index_link != null && (tasks_arr [arr_index_link.data]).prop_cmp (old_tasks_link.data) > 0) {
                arr_index_link = arr_index_link.next;
            }
            if (arr_index_link == null) {
                break;
            }
            while (old_tasks_link != null && (tasks_arr [arr_index_link.data]).prop_cmp (old_tasks_link.data) < 0) {
                // Task seems to be removed, signal that this task shouldn't be used anymore
                old_tasks_link.data.invalidate ();
                old_tasks_link = old_tasks_link.next;
            }
            if (old_tasks_link != null) {
                var old_task = old_tasks_link.data;
                var new_task = tasks_arr [arr_index_link.data];
                if (old_task.done != new_task.done) {
                    if ((old_task.done = new_task.done) == true) {
                        // Task seems to be completed now, so it shouldn't be used elsewhere
                        old_task.invalidate ();
                    }
                }
                if (timer_logged_in_txt || new_task.timer_value != 0) {
                    if ((old_task.status & TaskStatus.TIMER_ACTIVE) == 0 ||
                        new_task.timer_value > old_task.timer_value
                    ) {
                        old_task.timer_value = new_task.timer_value;
                    }
                }
                tasks_arr [arr_index_link.data] = old_task;
            }
        }
    }

    /**
     * Saves tasks to a Todo.txt formatted file.
     */
    private void write_task_file (TaskStore[] stores, File file) {
        if (io_failed) {
            return;
        }
        message ("Writing todo.txt file: %s\n", file.get_uri ());

        try {
            ensure_file_exists (file);
            var file_out_stream =
                file.replace (null, true, FileCreateFlags.NONE);
            var stream_out =
                new DataOutputStream (file_out_stream);

            foreach (var store in stores) {
                write_tasks_to_stream (store, stream_out, lsettings.log_timer_in_txt);
            }
        } catch (Error e) {
            io_failed = true;
            var error_message =
                write_error_message.printf (file.get_uri (), e.message) +
                ERROR_IMPLICATIONS.printf (APP_NAME);
            warning (error_message);
            show_error_dialog (error_message);
        }
    }

    private void write_tasks_to_stream (TaskStore store, DataOutputStream stream_out, bool log_timer) throws Error {
        uint n_items = store.get_n_items ();
        for (uint i = 0; i < n_items; i++) {
            TxtTask task = (TxtTask)store.get_item (i);
            stream_out.put_string (task.to_txt (log_timer));
            stream_out.put_byte ('\n');
        }
    }
}
