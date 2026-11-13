/* Copyright 2026 GoForIt! developers
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
 * Suggests the +projects and @contexts used in a TaskStore while the user
 * types a new task.
 *
 * Only the last word of the entry is completed, and only when it starts with
 * '+' or '@'. Matching is case-insensitive. Matching tags are listed in a
 * popover above the entry; the part all of them share is also filled in
 * inline (selected, so typing on replaces it).
 *
 * Keys: Tab or Right accepts the inline part, Up/Down select a tag in the
 * list, Enter or Tab inserts the selected tag, Escape closes the list.
 *
 * Gtk.EntryCompletion is not used: its popup is a separate window that is
 * placed with screen coordinates, which ends up in the wrong place on
 * Wayland. A popover is part of the main window and is always placed right.
 */
class GOFI.TXT.TagCompletion : Object {
    private const int MAX_VISIBLE_ROWS = 8;

    private unowned Gtk.Entry entry;
    private unowned TaskStore model;
    private Gtk.Popover popover;
    private Gtk.ScrolledWindow scroll;
    private Gtk.ListBox list;

    private string[] tags = {};
    private bool tags_outdated = true;
    private bool inserting = false;
    private int last_length = 0;
    // Shared prefix shown inline, in the spelling of the stored tags.
    private string? inline_prefix = null;
    // Entry text as typed, without the inline suggestion; null if there is
    // no suggestion shown.
    private string? typed_text = null;

    public TagCompletion (Gtk.Entry entry, TaskStore model) {
        this.entry = entry;
        this.model = model;

        list = new Gtk.ListBox ();
        list.selection_mode = Gtk.SelectionMode.SINGLE;
        list.activate_on_single_click = true;
        list.row_activated.connect ((row) => {
            accept_tag (((Gtk.Label) row.get_child ()).label);
        });

        scroll = new Gtk.ScrolledWindow (null, null);
        scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
        scroll.propagate_natural_height = true;
        scroll.add (list);

        popover = new Gtk.Popover (entry);
        popover.modal = false;
        popover.position = Gtk.PositionType.TOP;
        popover.add (scroll);
        scroll.show_all ();

        entry.changed.connect_after (on_entry_changed);
        entry.key_press_event.connect (on_key_press);
        entry.focus_out_event.connect (() => {
            popover.popdown ();
            return false;
        });

        model.task_data_changed.connect (() => {
            tags_outdated = true;
        });
    }

    /**
     * Returns the word that is currently being typed: the part of the text
     * after the last space.
     */
    private static string last_word (string text) {
        int space = text.last_index_of_char (' ');
        return text.substring (space + 1);
    }

    private static bool is_tag_word (string word) {
        return word.length >= 1 && (word[0] == '+' || word[0] == '@');
    }

    private static bool tag_matches (string tag, string word) {
        return tag[0] == word[0] &&
               tag.length > word.length &&
               tag.casefold ().has_prefix (word.casefold ());
    }

    private void update_tags () {
        if (!tags_outdated) {
            return;
        }
        tags_outdated = false;

        var seen = new GenericSet<string> (str_hash, str_equal);
        var sorted = new GenericArray<string> ();
        uint n_tasks = model.get_n_items ();
        for (uint i = 0; i < n_tasks; i++) {
            var task = model.get_task (i);
            foreach (unowned TxtPart part in task.get_descr_parts ()) {
                string tag;
                if (part.part_type == TxtPartType.PROJECT) {
                    tag = "+" + part.content;
                } else if (part.part_type == TxtPartType.CONTEXT) {
                    tag = "@" + part.content;
                } else {
                    continue;
                }
                if (!seen.contains (tag)) {
                    seen.add (tag);
                    sorted.add (tag);
                }
            }
        }
        sorted.sort ((a, b) => a.collate (b));
        tags = sorted.data;
    }

    private string[] get_matches (string word) {
        string[] matches = {};
        foreach (unowned string tag in tags) {
            if (tag_matches (tag, word)) {
                matches += tag;
            }
        }
        return matches;
    }

    private void on_entry_changed () {
        if (inserting) {
            return;
        }
        inline_prefix = null;
        typed_text = null;
        string text = entry.text;
        bool grew = text.length > last_length;
        last_length = text.length;

        string word = last_word (text);
        if (!is_tag_word (word)) {
            popover.popdown ();
            return;
        }
        update_tags ();
        string[] matches = get_matches (word);
        show_matches (matches, text.char_count () - word.char_count ());

        // Fill in the part all matches share, but only while typing at the
        // end of the text, never after deleting: Backspace then removes the
        // suggestion instead of having it come back.
        if (!grew || matches.length == 0) {
            return;
        }
        string prefix = matches[0];
        foreach (unowned string tag in matches) {
            prefix = common_prefix (prefix, tag);
        }
        if (prefix.length <= word.length) {
            return;
        }
        string addition = prefix.substring (word.length);
        // Let GTK finish handling the key press first, otherwise it moves the
        // cursor after our selection is set.
        Idle.add (() => {
            if (entry.text != text) {
                return Source.REMOVE;
            }
            inserting = true;
            int pos = entry.text.char_count ();
            entry.insert_text (addition, -1, ref pos);
            inserting = false;
            entry.select_region (text.char_count (), -1);
            inline_prefix = prefix;
            typed_text = text;
            return Source.REMOVE;
        });
    }

    /**
     * Fills the list with the matching tags and shows it, pointing at the
     * word being completed.
     */
    private void show_matches (string[] matches, int word_start) {
        list.foreach ((child) => child.destroy ());
        if (matches.length == 0) {
            popover.popdown ();
            return;
        }
        foreach (unowned string tag in matches) {
            var label = new Gtk.Label (tag);
            label.xalign = 0;
            label.margin_start = label.margin_end = 6;
            label.margin_top = label.margin_bottom = 2;
            list.add (label);
        }
        list.show_all ();

        int row_height;
        list.get_row_at_index (0).get_preferred_height (null, out row_height);
        scroll.max_content_height = row_height * MAX_VISIBLE_ROWS;

        popover.pointing_to = word_rectangle (word_start);
        if (!popover.visible) {
            popover.popup ();
        }
    }

    /**
     * The position of the start of the word in entry coordinates, so the
     * popover points at the tag being typed instead of the entry's middle.
     */
    private Gdk.Rectangle word_rectangle (int word_start) {
        int layout_x, layout_y;
        entry.get_layout_offsets (out layout_x, out layout_y);
        var layout = entry.get_layout ();
        int index = entry.text_index_to_layout_index (
            entry.text.index_of_nth_char (word_start));
        Pango.Rectangle pos = layout.index_to_pos (index);

        Gtk.Allocation alloc;
        entry.get_allocation (out alloc);
        Gdk.Rectangle rect = { 0, 0, 1, alloc.height };
        rect.x = int.max (0, layout_x + pos.x / Pango.SCALE);
        return rect;
    }

    private void accept_tag (string tag) {
        string text = typed_text ?? entry.text;
        int space = text.last_index_of_char (' ');
        inserting = true;
        entry.text = text.substring (0, space + 1) + tag + " ";
        inserting = false;
        typed_text = null;
        inline_prefix = null;
        last_length = entry.text.length;
        popover.popdown ();
        entry.grab_focus_without_selecting ();
        entry.set_position (-1);
    }

    /**
     * Replaces the word with the inline suggestion, in the spelling of the
     * stored tag: "+pro" becomes "+Prowler", not "+prowler". The list stays
     * open for the tags that still match.
     */
    private void accept_inline () {
        string text = typed_text ?? entry.text;
        int space = text.last_index_of_char (' ');
        string new_text = text.substring (0, space + 1) + inline_prefix;
        inline_prefix = null;
        typed_text = null;
        inserting = true;
        entry.text = new_text;
        inserting = false;
        last_length = new_text.length;
        entry.set_position (-1);
        string word = last_word (new_text);
        show_matches (get_matches (word),
                      new_text.char_count () - word.char_count ());
    }

    private void move_selection (int step) {
        var selected = list.get_selected_row ();
        int n = (int) list.get_children ().length ();
        int index = (selected == null) ?
            (step > 0 ? 0 : n - 1) :
            (selected.get_index () + step + n) % n;
        var row = list.get_row_at_index (index);
        list.select_row (row);
        // Keep the selected row visible.
        Gtk.Allocation alloc;
        row.get_allocation (out alloc);
        var adj = scroll.vadjustment;
        if (alloc.y < adj.value) {
            adj.value = alloc.y;
        } else if (alloc.y + alloc.height > adj.value + adj.page_size) {
            adj.value = alloc.y + alloc.height - adj.page_size;
        }
    }

    private bool on_key_press (Gdk.EventKey event) {
        bool list_shown = popover.visible;
        var selected = list_shown ? list.get_selected_row () : null;

        switch (event.keyval) {
            case Gdk.Key.Down:
            case Gdk.Key.KP_Down:
                if (!list_shown) {
                    return false;
                }
                move_selection (1);
                return true;
            case Gdk.Key.Up:
            case Gdk.Key.KP_Up:
                if (!list_shown) {
                    return false;
                }
                move_selection (-1);
                return true;
            case Gdk.Key.Escape:
                if (!list_shown) {
                    return false;
                }
                popover.popdown ();
                return true;
            case Gdk.Key.Return:
            case Gdk.Key.KP_Enter:
                // Without a selected tag, Enter adds the task as before.
                if (selected == null) {
                    return false;
                }
                accept_tag (((Gtk.Label) selected.get_child ()).label);
                return true;
            case Gdk.Key.Tab:
                if (selected != null) {
                    accept_tag (((Gtk.Label) selected.get_child ()).label);
                    return true;
                }
                if (inline_prefix != null) {
                    accept_inline ();
                    return true;
                }
                return false;
            case Gdk.Key.Right:
                if (inline_prefix != null) {
                    accept_inline ();
                    return true;
                }
                return false;
            default:
                return false;
        }
    }

    private static string common_prefix (string a, string b) {
        string fa = a.casefold ();
        string fb = b.casefold ();
        int n = int.min (fa.char_count (), fb.char_count ());
        int i = 0;
        while (i < n && fa.get_char (fa.index_of_nth_char (i)) ==
                        fb.get_char (fb.index_of_nth_char (i))) {
            i++;
        }
        return a.substring (0, a.index_of_nth_char (i));
    }
}
