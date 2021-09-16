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

/**
 * A widget for displaying and manipulating task lists.
 */
class GOFI.TXT.TaskListWidget : Gtk.Bin {
    /* GTK Widgets */
    // private Gtk.ScrolledWindow scroll_view;
    private DragList task_view;
    private Gtk.Label placeholder;

    /* Data Model */
    private TaskStore model;
    private TaskRow? active_row;

    private const string PLACEHOLDER_TEXT_TODO = _("You currently don't have any tasks.\nAdd some!");
    private const string FILTER_TEXT = _("No tasks found.");
    private const string PLACEHOLDER_TEXT_DONE = _("You don't have any completed tasks stored.");
    private const string PLACEHOLDER_TEXT_FINISHED = _("You finished all tasks, good job!");
    private string placeholder_text;

    public Gtk.Adjustment? list_adjustment {
        get {
            return task_view.vadjustment;
        }
        set {
            task_view.vadjustment = value;
        }
    }

    public string empty_list_text {
        get {
            return _empty_list_text;
        }
        set {
            // if (!filtering && show_placeholder) {
            //     placeholder.text = value;
            // }
            _empty_list_text = value;
        }
        // default = FILTER_TEXT;
    }
    private string _empty_list_text;

    /* Signals */
    public signal void selection_changed (TxtTask selected_task);

    [Signal (action = true)]
    public virtual signal void sort_tasks () {
        model.sort ();
    }

    [Signal (action = true)]
    public virtual signal void task_edit_action () {
        task_view.activate_cursor_row ();
        warning ("task_edit_action: STUB!");
    }

    /**
     * Constructor of the TaskListWidget class.
     */
    public TaskListWidget (TaskStore model) {
        /* Settings of the widget itself */
        // this.orientation = Gtk.Orientation.VERTICAL;
        this.expand = true;
        this.model = model;

        /* Setup the widget's children */
        setup_task_view ();
        _empty_list_text = FILTER_TEXT;
        placeholder_text = PLACEHOLDER_TEXT_TODO;
        add_placeholder ();
    }

    public TxtTask? get_selected_task () {
        if (active_row != null) {
            return active_row.task;
        }
        var first_item = (TxtTask) model.get_item (0);
        if (first_item != null) {
            return first_item;
        }
        return null;
    }

    public void select_task (TxtTask task) {
        warning ("select_task: STUB!");
    }

    public void move_cursor (int amount) {
        task_view.move_cursor (Gtk.MovementStep.DISPLAY_LINES, amount);
        warning ("move_cursor: STUB!");
    }

    public void move_selected_task (int amount) {
        warning ("move_selected_task called!");
    }

    private Gtk.Widget create_row (Object task) {
        TaskRow row = new TaskRow (((TxtTask) task));
        row.link_clicked.connect (on_row_link_clicked);
        row.deletion_requested.connect (on_deletion_requested);
        row.task_selected.connect (on_task_view_row_selected);
        return row;
    }

    private void on_row_link_clicked (string uri) {
        warning ("on_row_link_clicked: STUB!");
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
    private void setup_task_view () {
        this.task_view = new DragList ();

        task_view.bind_model ((DragListModel)model, create_row);
        task_view.row_activated.connect (on_task_view_row_activated);
        task_view.activate_on_single_click = true;
        task_view.selection_mode = Gtk.SelectionMode.NONE;

        this.add (task_view);
    }

    private void on_task_view_row_selected (DragListRow? selected_row) {
        TxtTask? task = null;
        if (selected_row != null) {
            task = ((TaskRow) selected_row).task;
        }
        active_row = (TaskRow) selected_row;
        selection_changed (task);
    }

    private void on_task_view_row_activated (DragListRow? selected_row) {
       ((TaskRow) selected_row).edit (true);
    }
}
