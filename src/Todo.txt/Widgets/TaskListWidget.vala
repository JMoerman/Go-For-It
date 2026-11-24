/* Copyright 2014-2019 GoForIt! developers
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

/**
 * A widget for displaying and manipulating task lists.
 */
class GOFI.TXT.TaskListWidget : Gtk.Grid {
    /* GTK Widgets */
    private Gtk.ScrolledWindow scroll_view;
    private DragList task_view;
    private Gtk.Grid add_new_grid;
    private Gtk.SearchBar search_bar;
    private Gtk.Entry add_new_txt;
    private Gtk.SearchEntry filter_entry;
    private Filter filter;
    private Gtk.Label placeholder;

    /* Data Model */
    private TaskStore model;

    /*
     * Done list only: newest first; rows are created for the newest tasks
     * once the list is shown, and for the rest when the user scrolls to the
     * end of the list or searches.
     */
    private RecentTasksModel? recent_model = null;
    private Gtk.Revealer? recent_bar = null;
    private Gtk.Label recent_label;
    private Gtk.Spinner recent_spinner;
    private Gtk.Button recent_show_all;
    private uint load_step_id = 0;
    private const uint INITIAL_DONE_ROWS = 200;
    private const uint ROWS_PER_STEP = 100;

    private const string PLACEHOLDER_TEXT_TODO = _("You currently don't have any tasks.\nAdd some!");
    private const string FILTER_TEXT = _("No tasks found.");
    private const string PLACEHOLDER_TEXT_DONE = _("You don't have any completed tasks stored.");
    private const string PLACEHOLDER_TEXT_FINISHED = _("You finished all tasks, good job!");
    private string placeholder_text;

    /* Signals */
    public signal void add_new_task (string task);
    public signal void selection_changed (TxtTask selected_task);

    [Signal (action = true)]
    public virtual signal void toggle_filtering () {
        is_filtering = !is_filtering;
    }

    [Signal (action = true)]
    public virtual signal void sort_tasks () {
        model.sort ();
    }

    [Signal (action = true)]
    public virtual signal void task_edit_action () {
        var selected_row = task_view.get_selected_row () as TaskRow;
        if (selected_row != null) {
            selected_row.edit (false);
        }
    }

    public bool is_filtering {
        public get {
            return search_bar.search_mode_enabled;
        }
        public set {
            search_bar.set_search_mode (value);
        }
    }

    /**
     * Constructor of the TaskListWidget class.
     * @param add_new whether or not to show a textfield for adding new entries
     */
    public TaskListWidget (TaskStore model, bool add_new = false) {
        /* Settings of the widget itself */
        this.orientation = Gtk.Orientation.VERTICAL;
        this.expand = true;
        this.model = model;

        /* Setup the widget's children */
        setup_filter ();
        setup_task_view (!add_new);
        if (add_new) {
            setup_add_new ();
            placeholder_text = PLACEHOLDER_TEXT_TODO;
        } else {
            add_new_txt = null;
            placeholder_text = PLACEHOLDER_TEXT_DONE;
        }
        add_placeholder ();
    }

    public TxtTask? get_selected_task () {
        TaskRow selected_row = (TaskRow) task_view.get_selected_row ();
        if (selected_row != null) {
            return selected_row.task;
        }
        return null;
    }

    public void select_task (TxtTask task) {
        int pos;
        if (recent_model != null) {
            pos = recent_model.get_position (task);
            if (pos < 0) {
                return;
            }
        } else {
            pos = (int) model.get_task_position (task);
        }
        var row = task_view.get_row_at_index (pos);
        task_view.select_row (row);
    }

    public void move_cursor (int amount) {
        TaskRow selected_row = (TaskRow) task_view.get_selected_row ();
        if (selected_row == null) {
            return;
        }

        // move_cursor was likely called because of a shortcut key, in this case
        // this key was meant for input for this row so we should ignore it.
        if (selected_row.is_editing) {
            return;
        }
        task_view.move_cursor (Gtk.MovementStep.DISPLAY_LINES, amount);
    }

    public void move_selected_task (int amount) {
        var row = task_view.get_selected_row ();
        if (row == null) {
            return;
        }
        var new_index = row.get_index ();
        if (new_index < -amount) {
            new_index = 0;
        } else {
            new_index += amount;
        }
        task_view.move_row (row, new_index);
    }

    private Gtk.Widget create_row (Object task) {
        TaskRow row = new TaskRow (((TxtTask) task));
        row.link_clicked.connect (on_row_link_clicked);
        row.deletion_requested.connect (on_deletion_requested);
        return row;
    }

    private void on_row_link_clicked (string uri) {
        is_filtering = true;
        filter_entry.set_text (uri);
    }

    private void on_deletion_requested (TaskRow row) {
        model.remove_task (row.task);
    }

    private void add_placeholder () {
        placeholder = new Gtk.Label (placeholder_text);
        placeholder.margin = 10;
        placeholder.wrap = true;
        placeholder.justify = Gtk.Justification.CENTER;
        placeholder.wrap_mode = Pango.WrapMode.WORD_CHAR;
        placeholder.width_request = 200;
        task_view.set_placeholder (placeholder);
        placeholder.show ();
    }

    /**
     * Configures the list to display the task entries.
     */
    private void setup_task_view (bool done_list) {
        this.scroll_view = new Gtk.ScrolledWindow (null, null);
        this.task_view = new DragList ();

        if (done_list) {
            // No rows until the list is shown for the first time
            recent_model = new RecentTasksModel (model, 0);
            task_view.bind_model (recent_model, create_row);
            map.connect (on_first_map);
            destroy.connect (() => {
                if (load_step_id != 0) {
                    Source.remove (load_step_id);
                    load_step_id = 0;
                }
            });
        } else {
            task_view.bind_model ((DragListModel)model, create_row);
        }
        task_view.vadjustment = scroll_view.vadjustment;
        task_view.row_selected.connect (on_task_view_row_selected);
        task_view.row_activated.connect (on_task_view_row_activated);
        task_view.set_filter_func (filter.filter);

        scroll_view.expand = true;

        // Add to the main widget
        scroll_view.add (task_view);
        if (done_list) {
            this.add (create_recent_bar ());
        }
        this.add (scroll_view);
    }

    private void on_task_view_row_selected (DragListRow? selected_row) {
        TxtTask? task = null;
        if (selected_row != null) {
            task = ((TaskRow) selected_row).task;
        }
        selection_changed (task);
    }

    private void on_task_view_row_activated (DragListRow? selected_row) {
       ((TaskRow) selected_row).edit (true);
    }

    /**
     * Configures the container with the "add new task" text entry.
     */
    private void setup_add_new () {
        add_new_grid = new Gtk.Grid ();
        add_new_grid.orientation = Gtk.Orientation.HORIZONTAL;

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

        add_new_grid.add (add_new_txt);

        var sc = kbsettings.get_shortcut (KeyBindingSettings.SCK_ADD_NEW);
        add_new_grid.tooltip_markup = sc.get_accel_markup (_("Add new task"));

        // Add to the main widget
        this.add (add_new_grid);
    }

    private void on_add_new_txt_icon_press (Gtk.EntryIconPosition pos, Gdk.Event event) {
        if (pos == Gtk.EntryIconPosition.SECONDARY) {
            on_entry_activate ();
        }
    }

    private void on_entry_activate () {
        add_new_task (add_new_txt.text);
        add_new_txt.text = "";
        placeholder_text = PLACEHOLDER_TEXT_FINISHED;
        placeholder.label = PLACEHOLDER_TEXT_FINISHED;
    }

    public void entry_focus () {
        add_new_txt.grab_focus ();
    }

    private void on_search_bar_toggle () {
        if (search_bar.search_mode_enabled) {
            placeholder.label = FILTER_TEXT;
        } else {
            placeholder.label = placeholder_text;
        }
    }

    private void setup_filter () {
        search_bar = new Gtk.SearchBar ();
        filter_entry = new Gtk.SearchEntry ();
        filter = new Filter ();

        filter_entry.search_changed.connect (on_filter_entry_search_changed);
        search_bar.notify["search-mode-enabled"].connect (on_search_bar_toggle);

        search_bar.add (filter_entry);
        search_bar.set_show_close_button (true);

        this.add (search_bar);
    }

    private void on_filter_entry_search_changed () {
        filter.parse (filter_entry.text);
        task_view.invalidate_filter ();
        // Searching has to see all done tasks
        if (filter_entry.text != "") {
            load_all_done_rows ();
        }
    }

    private Gtk.Widget create_recent_bar () {
        recent_spinner = new Gtk.Spinner ();
        recent_label = new Gtk.Label (null);
        recent_label.wrap = true;
        recent_label.xalign = 0;
        recent_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        recent_label.hexpand = true;
        recent_show_all = new Gtk.Button.with_label (_("Show all"));
        recent_show_all.relief = Gtk.ReliefStyle.NONE;
        recent_show_all.valign = Gtk.Align.CENTER;
        recent_show_all.clicked.connect (load_all_done_rows);
        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        box.margin = 6;
        box.add (recent_spinner);
        box.add (recent_label);
        box.add (recent_show_all);
        recent_bar = new Gtk.Revealer ();
        // Without animation: every frame would lay out all rows again
        recent_bar.transition_type = Gtk.RevealerTransitionType.NONE;
        recent_bar.add (box);
        box.show_all ();
        recent_spinner.hide ();
        return recent_bar;
    }

    private void on_first_map () {
        map.disconnect (on_first_map);
        recent_model.changed.connect (update_recent_bar);
        scroll_view.vadjustment.value_changed.connect (on_scrolled);
        recent_model.limit = INITIAL_DONE_ROWS;
        if (filter_entry.text != "") {
            load_all_done_rows ();
        }
    }

    /**
     * Loads the older done tasks once the list is scrolled to within one
     * page of its end, whether by mouse wheel, scrollbar or keyboard (End,
     * Page Down). edge-reached is not emitted for every way of scrolling.
     */
    private void on_scrolled () {
        var adj = scroll_view.vadjustment;
        if (adj.value + 2 * adj.page_size >= adj.upper) {
            load_all_done_rows ();
        }
    }

    /**
     * Adds the rows of the older done tasks in small steps, so that the
     * window stays responsive and the progress can be shown.
     */
    private void load_all_done_rows () {
        if (recent_model == null || load_step_id != 0 ||
            recent_model.n_hidden == 0 || recent_model.limit == 0) {
            return;
        }
        recent_spinner.show ();
        recent_spinner.start ();
        load_step_id = Idle.add (() => {
            if (recent_model.n_hidden == 0) {
                recent_model.limit = uint.MAX;
                load_step_id = 0;
                recent_spinner.stop ();
                recent_spinner.hide ();
                update_recent_bar ();
                return Source.REMOVE;
            }
            recent_model.limit = recent_model.get_n_items () + ROWS_PER_STEP;
            return Source.CONTINUE;
        }, Priority.DEFAULT_IDLE);
        update_recent_bar ();
    }

    private void update_recent_bar () {
        uint hidden = recent_model.n_hidden;
        uint total = hidden + recent_model.get_n_items ();
        recent_show_all.visible = load_step_id == 0 && hidden > 0;
        if (load_step_id != 0) {
            recent_label.label = _("Loading done tasks… %u of %u").printf (
                recent_model.get_n_items (), total);
            recent_bar.reveal_child = true;
        } else if (hidden > 0) {
            recent_label.label = _("Showing the newest %u of %u done tasks. Scroll to the end or search to show all.").printf (
                recent_model.get_n_items (), total);
            recent_bar.reveal_child = true;
        } else {
            recent_bar.reveal_child = false;
        }
    }
}
