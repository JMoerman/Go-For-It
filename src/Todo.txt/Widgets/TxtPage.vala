class GOFI.TXT.TxtPage : Gtk.Grid {
    private Gtk.Grid list_header;

    private Gtk.MenuButton list_menu_button;
    private Gtk.Button add_button;

    private Gtk.Label list_name_label;

    private Gtk.Stack lists_stack;

    private TaskListWidget todo_list;
    private TaskListWidget done_list;

    private ListSettings lsettings;

    private Gtk.Box menu_box;
    private Gtk.Popover menu_popover;

    public signal void sort_tasks_activated ();
    public signal void clear_done_activated ();
    public signal void add_task_clicked ();

    public TxtPage (ListSettings lsettings, TaskListWidget todo_list, TaskListWidget done_list) {
        this.lsettings = lsettings;
        this.todo_list = todo_list;
        this.done_list = done_list;
        this.orientation = Gtk.Orientation.VERTICAL;

        setup_content ();
        connect_signals ();
    }

    private void setup_content () {
        list_name_label = new Gtk.Label (lsettings.name);
        list_menu_button = new Gtk.MenuButton ();
        add_button = new Gtk.Button.from_icon_name ("list-add-symbolic");

        var menu_img = GOFI.Utils.load_image_fallback (
            Gtk.IconSize.BUTTON, "edit-symbolic", "edit",
            "document-edit-symbolic", "view-more-symbolic"
        );


        list_menu_button.image = menu_img;

        var clear_done_button = new Gtk.ModelButton ();
        clear_done_button.text = _("Clear Done List");
        clear_done_button.clicked.connect (on_clear_done_clicked);

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
        sort_tasks_button.clicked.connect (on_sort_tasks_clicked);

        menu_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        menu_box.add (sort_tasks_button);
        menu_box.add (clear_done_button);
        menu_box.show_all ();


        menu_popover = new Gtk.Popover (list_menu_button);
        menu_popover.add (menu_box);
        menu_popover.get_style_context ().add_class ("menu");

#if !USE_GRANITE
        menu_box.margin = 10;
#endif
        list_menu_button.popover = menu_popover;


        list_header = new Gtk.Grid ();
        list_header.orientation = Gtk.Orientation.HORIZONTAL;
        list_header.column_spacing = 6;
        list_header.add (add_button);
        list_header.add (list_name_label);
        list_header.add (list_menu_button);
        list_name_label.hexpand = true;
        list_name_label.halign = Gtk.Align.START;
        list_header.hexpand = true;

        lists_stack = new Gtk.Stack ();
        lists_stack.set_transition_type (
            Gtk.StackTransitionType.SLIDE_UP_DOWN
        );

        lists_stack.add_titled (todo_list, "todo_list", _("To-Do"));
        lists_stack.add_titled (done_list, "done_list", _("Done"));

        this.add (list_header);
        this.add (lists_stack);
        this.show_all ();
    }

    private void connect_signals () {
        lsettings.notify.connect (on_lsettings_property_changed);
        add_button.clicked.connect (() => add_task_clicked());
    }

    private void on_lsettings_property_changed (ParamSpec pspec) {
        switch (pspec.name) {
            case "name":
                list_name_label.label = lsettings.name;
                break;
        }
    }

    private void on_sort_tasks_clicked () {
        sort_tasks_activated ();
    }

    private void on_clear_done_clicked () {
        clear_done_activated ();
    }
}
