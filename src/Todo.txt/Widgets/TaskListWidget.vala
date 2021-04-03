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
class GOFI.TXT.TaskListWidget : Gtk.Grid {
    /* GTK Widgets */
    private Gtk.ScrolledWindow scroll_view;
    private DragList task_view;
    private Gtk.Label placeholder;

    /* Data Model */
    private TaskStore model;

    private const string PLACEHOLDER_TEXT_TODO = _("You currently don't have any tasks.\nAdd some!");
    private const string FILTER_TEXT = _("No tasks found.");
    private const string PLACEHOLDER_TEXT_DONE = _("You don't have any completed tasks stored.");
    private const string PLACEHOLDER_TEXT_FINISHED = _("You finished all tasks, good job!");
    private string placeholder_text;

    /* Signals */
    public signal void add_new_task (string task);
    public signal void selection_changed (TxtTask selected_task);

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

    /**
     * Constructor of the TaskListWidget class.
     */
    public TaskListWidget (TaskStore model) {
        /* Settings of the widget itself */
        this.orientation = Gtk.Orientation.VERTICAL;
        this.expand = true;
        this.model = model;

        /* Setup the widget's children */
        setup_task_view ();
        placeholder_text = PLACEHOLDER_TEXT_TODO;
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
        var pos = model.get_task_position (task);
        var row = task_view.get_row_at_index ((int)pos);
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
        warning ("STUB!");
        // is_filtering = true;
        // filter_entry.set_text (uri);
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
        this.scroll_view = new Gtk.ScrolledWindow (null, null);
        this.task_view = new DragList ();

        task_view.bind_model ((DragListModel)model, create_row);
        task_view.vadjustment = scroll_view.vadjustment;
        task_view.row_selected.connect (on_task_view_row_selected);
        task_view.row_activated.connect (on_task_view_row_activated);

        scroll_view.expand = true;

        // Add to the main widget
        scroll_view.add (task_view);
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
}
