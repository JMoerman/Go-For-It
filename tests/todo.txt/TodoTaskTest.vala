using GOFI.TXT;

class TodoTaskTest : TestCase {
    private uint data_changed_emitted;
    private uint done_changed_emitted;
    private uint notify_done_emitted;

    public TodoTaskTest () {
        base ("TodoTask");
        add_test ("retrieve", test_retreive);
        add_test ("modify_title", test_modify_string);
        add_test ("modify_done", test_modify_done);
        add_test ("from_todo_txt", test_from_txt);
        add_test ("to_todo_txt", test_to_txt);
    }

    private bool check_expected (uint data_changed, uint done_changed, uint notify_done) {
        bool matched = true;
        if (data_changed != data_changed_emitted) {
            stdout.printf (
                "data_changed emitted %u times, expected %u\n",
                data_changed_emitted,
                data_changed
            );
            matched = false;
        }
        if (done_changed != done_changed_emitted) {
            stdout.printf (
                "done_changed emitted %u times, expected %u\n",
                done_changed_emitted,
                done_changed
            );
            matched = false;
        }
        if (notify_done != notify_done_emitted) {
            stdout.printf (
                "notify[\"done\"] emitted %u times, expected %u\n",
                notify_done_emitted,
                notify_done
            );
            matched = false;
        }
        return matched;
    }

    private void reset_counters () {
        data_changed_emitted = 0;
        done_changed_emitted = 0;
        notify_done_emitted = 0;
    }

    private void connect_task (TxtTask task) {
        task.done_changed.connect (on_task_done_changed);
        task.notify.connect (on_task_property_changed);
    }

    private void disconnect_task (TxtTask task) {
        task.done_changed.disconnect (on_task_done_changed);
        task.notify.disconnect (on_task_property_changed);
    }

    private void on_task_property_changed (Object task, ParamSpec pspec) {
        switch (pspec.name) {
            case "done":
                notify_done_emitted++;
                break;
            default:
                data_changed_emitted++;
                break;
        }
    }

    private void on_task_done_changed () {
        done_changed_emitted++;
    }

    private void test_retreive () {
        string test_title;
        bool done;

        for (int i = 0; i < 4; i++) {
            done = i % 2 == 0;
            test_title = "Task %i".printf (i);
            TxtTask test_task = new TxtTask (test_title, done);

            assert_cmpstr (test_task.description, CompareOperator.EQ, test_title);
            assert_true (compare_bool (test_task.done, done));
            assert_true (test_task.valid);
        }
    }

    private void test_modify_string () {
        string test_title;
        bool done;

        for (int i = 0; i < 4; i++) {
            done = i % 2 == 0;
            test_title = "Task %i".printf (i);

            TxtTask task = new TxtTask (test_title, done);

            reset_counters ();
            connect_task (task);

            string new_title = "new_title";
            task.description = new_title;

            assert_true (check_expected (1, 0, 0));
            assert_cmpstr (task.description, CompareOperator.EQ, new_title);
            assert_true (compare_bool (task.done, done));
            assert_true (task.valid);
            disconnect_task (task);
        }
        for (int i = 4; i < 6; i++) {
            done = i % 2 == 0;
            test_title = "Task %i".printf (i);

            TxtTask task = new TxtTask (test_title, done);

            reset_counters ();
            connect_task (task);

            string new_title = "";
            task.description = new_title;

            assert_true (check_expected (1, 0, 0));
            assert_cmpstr (task.description, CompareOperator.EQ, new_title);
            assert_true (compare_bool (task.done, done));
            assert_true (!task.valid);
            disconnect_task (task);
        }
    }

    private void test_modify_done () {
        string test_title;
        bool done;

        for (int i = 0; i < 2; i++) {
            done = i % 2 == 0;
            test_title = "Task %i".printf (i);

            TxtTask task = new TxtTask (test_title, done);

            reset_counters ();
            connect_task (task);

            task.done = !done;

            assert_true (check_expected (0, 1, 1));
            assert_cmpstr (task.description, CompareOperator.EQ, test_title);
            assert_true (compare_bool (task.done, !done));
            assert_true (task.valid);
            disconnect_task (task);
        }
        for (int i = 2; i < 4; i++) {
            done = i % 2 == 0;
            test_title = "Task %i".printf (i);

            TxtTask task = new TxtTask (test_title, done);

            reset_counters ();
            connect_task (task);

            task.done = done;

            assert_true (check_expected (0, 0, 1));
            assert_cmpstr (task.description, CompareOperator.EQ, test_title);
            assert_true (compare_bool (task.done, done));
            assert_true (task.valid);
            disconnect_task (task);
        }
    }

    private static TxtTask build_test_task1 () {
        TxtTask task = new TxtTask ("Test task", false);
        return task;
    }
    private const string TEST_TASK1_TXT = "Test task";

    private static TxtTask build_test_task2 () {
        TxtTask task = new TxtTask ("Test task +project @context key:value", true);
        task.completion_date = new GOFI.Date.from_ymd (2021, 11, 15);
        task.creation_date = new GOFI.Date.from_ymd (2020, 10, 13);
        task.timer_value = (((1 * 60) + 2) * 60) + 3;
        task.duration = 15 * 60;
        task.priority = 1;
        return task;
    }
    private const string TEST_TASK2_TXT = "x (B) 2021-11-15 2020-10-13 Test task +project @context timer:1h-2m-3s duration:15m key:value";

    private static TxtTask build_test_task3 () {
        TxtTask task = new TxtTask ("2020-10-13 @context +project Test task", false);
        task.creation_date = new GOFI.Date.from_ymd (2021, 11, 15);
        task.priority = 0;
        return task;
    }
    private const string TEST_TASK3_TXT = "(A) 2021-11-15 2020-10-13 @context +project Test task";

    private void test_from_txt () {
        string? error_str = build_test_task1 ().assert_equal (new TxtTask.from_todo_txt (TEST_TASK1_TXT, false));
        if (error_str != null) { stdout.printf ("%s\n", error_str); assert_not_reached (); }
        error_str = build_test_task2 ().assert_equal (new TxtTask.from_todo_txt (TEST_TASK2_TXT, false));
        if (error_str != null) { stdout.printf ("%s\n", error_str); assert_not_reached (); }
        error_str = build_test_task2 ().assert_equal (new TxtTask.from_todo_txt (TEST_TASK2_TXT.offset (2), true));
        if (error_str != null) { stdout.printf ("%s\n", error_str); assert_not_reached (); }
        error_str = build_test_task3 ().assert_equal (new TxtTask.from_todo_txt (TEST_TASK3_TXT, false));
        if (error_str != null) { stdout.printf ("%s\n", error_str); assert_not_reached (); }
    }

    private void test_to_txt () {
        var initial_task = build_test_task1 ();
        var final_task = new TxtTask.from_todo_txt (initial_task.to_txt (true), false);
        string? error_str = initial_task.assert_equal (final_task);
        if (error_str != null) { stdout.printf ("%s\n", error_str); assert_not_reached (); }

        initial_task = build_test_task2 ();
        final_task = new TxtTask.from_todo_txt (initial_task.to_txt (true), false);
        error_str = initial_task.assert_equal (final_task);
        if (error_str != null) { stdout.printf ("%s\n", error_str); assert_not_reached (); }
        final_task = new TxtTask.from_todo_txt (initial_task.to_txt (false), false);
        assert_cmpuint (final_task.timer_value, CompareOperator.EQ, 0);
        final_task.timer_value = initial_task.timer_value;
        error_str = initial_task.assert_equal (final_task);
        if (error_str != null) { stdout.printf ("%s\n", error_str); assert_not_reached (); }

        initial_task = build_test_task3 ();
        final_task = new TxtTask.from_todo_txt (initial_task.to_txt (true), false);
        error_str = initial_task.assert_equal (final_task);
        if (error_str != null) { stdout.printf ("%s\n", error_str); assert_not_reached (); }
    }
}
