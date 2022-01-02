using GOFI.TXT;
using GOFI;

class TaskManagerTest : TestCase {
    private File todo_txt;
    private File done_txt;
    private ListSettings lsettings;

    public TaskManagerTest () {
        base ("TaskManager");
        add_test ("reference count", check_ref_count);
        add_test ("io", test_io);
        add_test ("io (single)", test_io_single);
        add_test ("timer logging", test_timer_logging);
        add_test ("no timer logging", test_no_timer_logging);
        add_test ("Repeat task 2 days from completion date (due date)", test_reschedule_completion_due_date);
        add_test ("Repeat task 2 days from completion date (threshold date)", test_reschedule_completion_threshold_date);
        add_test ("Repeat weekly task upon completing", test_reschedule_periodically);
        add_test ("Repeat task: every 3 months, skipping past dates", test_reschedule_monthly_skip);
        add_test ("Check drift compensation", test_reschedule_monthly_drift_compensation);
        add_test ("Repeat task: yearly reschedule", test_yearly_reschedule);
        add_test ("Checking if tasks are ordered as expected after completion of a recurring task", test_task_order);
        add_test ("Reschedule task when overdue", test_reschedule_overdue);
    }

    public override void set_up () {
        FileIOStream iostream;
        try {
            todo_txt = GLib.File.new_tmp ("gofi-test-todo-XXXXXX.txt", out iostream);
            done_txt = GLib.File.new_tmp ("gofi-test-done-XXXXXX.txt", out iostream);
        } catch (Error e) {
            Test.fail ();
        }

        assert_true (todo_txt != null);
        assert_true (done_txt != null);
        lsettings = new ListSettings ("test-id", "test-name", todo_txt.get_uri (), done_txt.get_uri ());
    }

    public override void tear_down () {
        try {
            todo_txt.@delete ();
            done_txt.@delete ();
        } catch (Error e) {
            warning ("%s", e.message);
        }

        todo_txt = null;
        done_txt = null;
        lsettings = null;
    }

    private void check_ref_count () {
        var task_manager = new TaskManager (lsettings);
        // var task_manager = new TaskManager.test_instance ();
        assert_cmpuint (task_manager.ref_count, CompareOperator.EQ, 1);
        task_manager.flush_changes_and_stop_monitoring ();
    }

    private void test_io () {
        var task_manager = new TaskManager (lsettings);
        assert_cmpuint (task_manager.todo_store.get_n_items (), CompareOperator.EQ, 0);
        assert_cmpuint (task_manager.done_store.get_n_items (), CompareOperator.EQ, 0);

        task_manager.add_new_task_from_txt ("test task 1");
        task_manager.add_new_task_from_txt ("test task 2");
        task_manager.add_new_task_from_txt ("test task 3");
        task_manager.new_tasks_on_top = true;
        task_manager.add_new_task_from_txt ("test task 4");
        task_manager.add_new_task_from_txt ("test task 5");
        task_manager.add_new_task_from_txt ("test task 6");

        task_manager.todo_store.get_task (0).done = true;
        task_manager.flush_changes_and_stop_monitoring ();
        task_manager = null;

        // Check if tasks are still there
        task_manager = new TaskManager (lsettings);
        var todo_store = task_manager.todo_store;
        assert_cmpstr (todo_store.get_task (0).description, CompareOperator.EQ, "test task 5");
        assert_cmpstr (todo_store.get_task (1).description, CompareOperator.EQ, "test task 4");
        assert_cmpstr (todo_store.get_task (2).description, CompareOperator.EQ, "test task 1");
        assert_cmpstr (todo_store.get_task (3).description, CompareOperator.EQ, "test task 2");
        assert_cmpstr (todo_store.get_task (4).description, CompareOperator.EQ, "test task 3");
        assert_cmpstr (task_manager.done_store.get_task (0).description, CompareOperator.EQ, "test task 6");

        assert_true (todo_store.get_task (5) == null);
        assert_true (task_manager.done_store.get_task (1) == null);
        task_manager.flush_changes_and_stop_monitoring ();
    }

    private void test_io_single () {
        lsettings.done_uri = lsettings.todo_uri;
        test_io ();
    }

    private void test_timer_logging () {
        lsettings.log_timer_in_txt = true;
        var task_manager = new TaskManager (lsettings);
        task_manager.add_new_task_from_txt ("test task 1");
        task_manager.todo_store.get_task (0).timer_value = 123;
        task_manager.flush_changes_and_stop_monitoring ();
        task_manager = null;

        task_manager = new TaskManager (lsettings);
        var timer_value = task_manager.todo_store.get_task (0).timer_value;
        assert_cmpuint (timer_value, CompareOperator.EQ, 123);
        task_manager.flush_changes_and_stop_monitoring ();
    }

    private void test_no_timer_logging () {
        lsettings.log_timer_in_txt = false;
        var task_manager = new TaskManager (lsettings);
        task_manager.add_new_task_from_txt ("test task 1");
        task_manager.todo_store.get_task (0).timer_value = 123;
        task_manager.flush_changes_and_stop_monitoring ();
        task_manager = null;

        task_manager = new TaskManager (lsettings);
        var timer_value = task_manager.todo_store.get_task (0).timer_value;
        assert_cmpuint (timer_value, CompareOperator.EQ, 0);
        task_manager.flush_changes_and_stop_monitoring ();
    }

    private static TxtTask build_test_2day_on_completion () {
        TxtTask task = new TxtTask ("Repeats two days after completion", false);
        task.recur = new GOFI.RecurrenceRule (GOFI.RecurrenceFrequency.DAILY_RECURRENCE, 2);
        task.recur_mode = GOFI.RecurrenceMode.ON_COMPLETION;
        return task;
    }

    private static TxtTask build_test_weekly () {
        TxtTask task = new TxtTask ("Repeats every week", false);
        task.recur = new GOFI.RecurrenceRule (GOFI.RecurrenceFrequency.WEEKLY_RECURRENCE, 1);
        task.recur_mode = GOFI.RecurrenceMode.PERIODICALLY;
        return task;
    }

    private static TxtTask build_test_3month_skip () {
        TxtTask task = new TxtTask ("Repeats on the last day of the month, every 3 months, discards overdue tasks", false);
        task.recur = new GOFI.RecurrenceRule (GOFI.RecurrenceFrequency.MONTHLY_RECURRENCE, 3, -1);
        task.recur_mode = GOFI.RecurrenceMode.PERIODICALLY_SKIP_OLD;
        return task;
    }

    private static TxtTask build_test_yearly_auto_reschedule () {
        TxtTask task = new TxtTask ("Task is rescheduled to the same day next year if overdue", false);
        task.recur = new GOFI.RecurrenceRule (GOFI.RecurrenceFrequency.YEARLY_RECURRENCE, 1);
        task.recur_mode = GOFI.RecurrenceMode.PERIODICALLY_AUTO_RESCHEDULE;
        return task;
    }

    private void test_reschedule_overdue () {
        var task_manager = new TaskManager.test_instance ();
        var test_date = new GOFI.Date.from_ymd (2021, 11, 15);
        task_manager.static_date = test_date.dt;
        TxtTask task = new TxtTask ("Task repeats every two days and is rescheduled if overdue", false);
        task.recur = new GOFI.RecurrenceRule (GOFI.RecurrenceFrequency.DAILY_RECURRENCE, 2);
        task.recur_mode = GOFI.RecurrenceMode.PERIODICALLY_AUTO_RESCHEDULE;
        task.due_date = new GOFI.Date.from_ymd (2021, 11, 16);
        task.threshold_date = new GOFI.Date.from_ymd (2021, 11, 14);
        task.creation_date = new GOFI.Date.from_ymd (2021, 10, 31);
        var task_copy = task.copy ();
        task_manager.todo_store.add_task (task);

        // Task shouldn't get rescheduled
        task_manager.reschedule_overdue_tasks ();
        assert_true (task_manager.todo_store.get_task (0) == task);
        compare_post_reschedule (task_copy, task, task_copy.threshold_date, task_copy.due_date);

        // Due date is one day in the past, so it should get rescheduled
        task_manager.static_date = new GOFI.Date.from_ymd (2021, 11, 17).dt;
        task_manager.reschedule_overdue_tasks ();
        assert_true (task_manager.todo_store.get_task (0) == task);
        var expected_due_date = new GOFI.Date.from_ymd (2021, 11, 18);
        var expected_threshold_date = new GOFI.Date.from_ymd (2021, 11, 16);
        compare_post_reschedule (task_copy, task, expected_threshold_date, expected_due_date);

        // Due date is on the current day, it shouldn't get rescheduled
        task_manager.static_date = expected_due_date.dt;
        task_manager.reschedule_overdue_tasks ();
        assert_true (task_manager.todo_store.get_task (0) == task);
        compare_post_reschedule (task_copy, task, expected_threshold_date, expected_due_date);

        // Tasks with only a threshold_date shouldn't get rescheduled
        task.due_date = null;
        task_manager.reschedule_overdue_tasks ();
        compare_post_reschedule (task_copy, task, expected_threshold_date, null);

        assert_cmpuint (task_manager.todo_store.get_n_items (), CompareOperator.EQ, 1);
        assert_cmpuint (task_manager.done_store.get_n_items (), CompareOperator.EQ, 0);
    }

    private void compare_post_reschedule (TxtTask initial_task, TxtTask rescheduled_task, GOFI.Date? threshold_date, GOFI.Date? due_date) {
        var expected_task = initial_task.copy ();
        expected_task.threshold_date = threshold_date;
        expected_task.due_date = due_date;
        compare_tasks_with_expected (
            "Rescheduled task differs from what is expected!",
            expected_task, rescheduled_task
        );
    }

    private void compare_post_schedule (TxtTask initial_task, TxtTask? completed_task, TxtTask generated_task, GOFI.Date? threshold_date, GOFI.Date? due_date, GOFI.Date? creation_date, GOFI.Date? completion_date) {
        if (completed_task != null) {
            var expected_task = initial_task.copy ();
            expected_task.recur_mode = GOFI.RecurrenceMode.NO_RECURRENCE;
            expected_task.recur = null;
            expected_task.done = true;
            expected_task.completion_date = completion_date;
            compare_tasks_with_expected (
                "Completed task changed in an unexpected way!",
                expected_task, completed_task
            );
        }
        var expected_task = initial_task.copy ();
        expected_task.threshold_date = threshold_date;
        expected_task.due_date = due_date;
        expected_task.creation_date = creation_date;
        expected_task.timer_value = 0;
        compare_tasks_with_expected (
            "Generated task differs from what is expected!",
            expected_task, generated_task
        );
    }

    private void compare_tasks_with_expected (string context_msg, TxtTask expected_task, TxtTask task) {
        string? error_str = expected_task.assert_equal (task);
        if (error_str != null) {
            stdout.printf (
                "%s\n" +
                "\texpected: \"%s\"\n" +
                "\tgot: \"%s\"\n" +
                "\terror: %s\n",
                    context_msg,
                    expected_task.to_txt (true),
                    task.to_txt (true),
                    error_str
            );
            Test.fail ();
        }
    }

    private void test_reschedule_completion_due_date () {
        var task_manager = new TaskManager.test_instance ();
        var task = build_test_2day_on_completion ();
        task.due_date = new GOFI.Date.from_ymd (2021, 11, 16);
        var task_copy = task.copy ();
        task_manager.todo_store.add_task (task);
        var test_date = new GOFI.Date.from_ymd (2021, 11, 15);
        task_manager.static_date = test_date.dt;
        task.set_completed (test_date);

        assert_true (task_manager.done_store.get_task (0) == task);

        var completed_task = task_manager.done_store.get_task (0);
        var generated_task = task_manager.todo_store.get_task (0);
        var due_date = new GOFI.Date.from_ymd (2021, 11, 17);
        var threshold_date = null;

        compare_post_schedule (task_copy, completed_task, generated_task, threshold_date, due_date, test_date, test_date);
    }

    private void test_reschedule_completion_threshold_date () {
        var task_manager = new TaskManager.test_instance ();
        var task = build_test_2day_on_completion ();
        task.threshold_date = new GOFI.Date.from_ymd (2021, 11, 16);
        var task_copy = task.copy ();
        task_manager.todo_store.add_task (task);
        var test_date = new GOFI.Date.from_ymd (2021, 11, 15);
        task_manager.static_date = test_date.dt;
        task.set_completed (test_date);

        assert_true (task_manager.done_store.get_task (0) == task);

        var completed_task = task_manager.done_store.get_task (0);
        var generated_task = task_manager.todo_store.get_task (0);
        var due_date = null;
        var threshold_date = new GOFI.Date.from_ymd (2021, 11, 17);

        compare_post_schedule (task_copy, completed_task, generated_task, threshold_date, due_date, test_date, test_date);
    }

    private void test_reschedule_periodically () {
        var task_manager = new TaskManager.test_instance ();
        var task = build_test_weekly ();
        task.due_date = new GOFI.Date.from_ymd (2021, 11, 16);
        var task_copy = task.copy ();
        task_manager.todo_store.add_task (task);
        var test_date = new GOFI.Date.from_ymd (2021, 11, 15);
        task_manager.static_date = test_date.dt;
        task.set_completed (test_date);

        assert_true (task_manager.done_store.get_task (0) == task);

        var completed_task = task_manager.done_store.get_task (0);
        var generated_task = task_manager.todo_store.get_task (0);
        var due_date = new GOFI.Date.from_ymd (2021, 11, 23);
        var threshold_date = null;

        compare_post_schedule (task_copy, completed_task, generated_task, threshold_date, due_date, test_date, test_date);
    }

    private void test_reschedule_monthly_skip () {
        var task_manager = new TaskManager.test_instance ();
        var task = build_test_3month_skip ();
        task.due_date = new GOFI.Date.from_ymd (2021, 01, 31);
        var task_copy = task.copy ();
        task_manager.todo_store.add_task (task);
        var test_date = new GOFI.Date.from_ymd (2021, 10, 03);
        task_manager.static_date = test_date.dt;
        task.set_completed (test_date);

        assert_true (task_manager.done_store.get_task (0) == task);

        var completed_task = task_manager.done_store.get_task (0);
        var generated_task = task_manager.todo_store.get_task (0);
        var due_date = new GOFI.Date.from_ymd (2021, 10, 31);
        var threshold_date = null;

        compare_post_schedule (task_copy, completed_task, generated_task, threshold_date, due_date, test_date, test_date);
    }

    private void test_reschedule_monthly_drift_compensation () {
        var task_manager = new TaskManager.test_instance ();
        TxtTask task = new TxtTask ("Repeats monthly", false);
        task.recur = new GOFI.RecurrenceRule (GOFI.RecurrenceFrequency.MONTHLY_RECURRENCE, 1, 30);
        task.recur_mode = GOFI.RecurrenceMode.PERIODICALLY;
        task.due_date = new GOFI.Date.from_ymd (2021, 01, 31);
        var task_copy = task.copy ();
        task_manager.todo_store.add_task (task);
        var test_date = new GOFI.Date.from_ymd (2021, 01, 26);
        task_manager.static_date = test_date.dt;
        task.set_completed (test_date);

        assert_true (task_manager.done_store.get_task (0) == task);

        var completed_task = task_manager.done_store.get_task (0);
        var generated_task = task_manager.todo_store.get_task (0);
        var due_date = new GOFI.Date.from_ymd (2021, 02, 28);
        var threshold_date = null;

        compare_post_schedule (task_copy, completed_task, generated_task, threshold_date, due_date, test_date, test_date);

        task_copy = generated_task.copy ();
        test_date = new GOFI.Date.from_ymd (2021, 02, 22);
        task_manager.static_date = test_date.dt;

        generated_task.set_completed (test_date);
        due_date = new GOFI.Date.from_ymd (2021, 03, 30);

        assert_true (task_manager.done_store.get_task (1) == generated_task);
        assert_true (task_manager.done_store.get_task (0) == completed_task);
        assert_cmpuint (task_manager.todo_store.get_n_items (), CompareOperator.EQ, 1);
        assert_cmpuint (task_manager.done_store.get_n_items (), CompareOperator.EQ, 2);

        completed_task = task_manager.done_store.get_task (1);
        generated_task = task_manager.todo_store.get_task (0);
        compare_post_schedule (task_copy, completed_task, generated_task, threshold_date, due_date, test_date, test_date);
    }

    private void test_yearly_reschedule () {
        var task_manager = new TaskManager.test_instance ();
        var task = build_test_yearly_auto_reschedule ();
        task.due_date = new GOFI.Date.from_ymd (2021, 12, 01);
        var task_copy = task.copy ();
        task_manager.todo_store.add_task (task);
        var test_date = new GOFI.Date.from_ymd (2021, 10, 03);
        task_manager.static_date = test_date.dt;
        task.set_completed (test_date);

        assert_true (task_manager.done_store.get_task (0) == task);

        var completed_task = task_manager.done_store.get_task (0);
        var generated_task = task_manager.todo_store.get_task (0);
        var due_date = new GOFI.Date.from_ymd (2022, 12, 01);
        var threshold_date = null;

        compare_post_schedule (task_copy, completed_task, generated_task, threshold_date, due_date, test_date, test_date);
    }

    private void test_task_order () {
        var task_manager = new TaskManager.test_instance ();
        var test_date = new GOFI.Date.from_ymd (2021, 11, 15);
        task_manager.static_date = test_date.dt;
        var task = build_test_2day_on_completion ();
        task.due_date = new GOFI.Date.from_ymd (2021, 11, 16);
        var task_copy = task.copy ();
        TxtTask[] tasks = new TxtTask[10];
        var todo_store = task_manager.todo_store;
        for (int i = 0; i < 5; i++) {
            tasks[i] = new TxtTask.from_simple_txt ("Test task %i".printf (i), false);
            todo_store.add_task (tasks[i]);
        }
        todo_store.add_task (task);
        for (int i = 5; i < 10; i++) {
            tasks[i] = new TxtTask.from_simple_txt ("Test task %i".printf (i), false);
            todo_store.add_task (tasks[i]);
        }
        task.set_completed (test_date);

        assert_true (task_manager.done_store.get_task (0) == task);
        assert_cmpuint (task_manager.todo_store.get_n_items (), CompareOperator.EQ, 11);
        assert_cmpuint (task_manager.done_store.get_n_items (), CompareOperator.EQ, 1);

        var completed_task = task_manager.done_store.get_task (0);
        var generated_task = todo_store.get_task (10);
        var due_date = new GOFI.Date.from_ymd (2021, 11, 17);
        var threshold_date = null;

        compare_post_schedule (task_copy, completed_task, generated_task, threshold_date, due_date, test_date, test_date);

        for (int i = 0; i < 10; i++) {
            if (tasks[i] != todo_store.get_task (i)) {
                stderr.printf ("tasks[%i] != todo_store.get_task (%i) (= %s)\n", i, i, todo_store.get_task (i).description);
                Test.fail ();
            }
        }
        task_manager.new_tasks_on_top = true;
        generated_task.set_completed (test_date);
        assert_cmpuint (task_manager.todo_store.get_n_items (), CompareOperator.EQ, 11);
        assert_cmpuint (task_manager.done_store.get_n_items (), CompareOperator.EQ, 2);
        for (int i = 0; i < 10; i++) {
            if (tasks[i] != todo_store.get_task (i+1)) {
                stderr.printf ("tasks[%i] != todo_store.get_task (%i+1 (= %s)\n", i, i, todo_store.get_task (i+1).description);
                Test.fail ();
            }
        }
    }
}
