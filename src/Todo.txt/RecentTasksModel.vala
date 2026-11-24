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
 * Shows only the last `limit` tasks of a TaskStore, i.e. the newest ones of
 * the "Done" list, newest first, so that a long history does not create a
 * row for every task.
 *
 * Newest first also means that showing more tasks appends rows at the end.
 * Inserting rows in front of others is expensive in GTK (every following
 * row is restyled), so growing the list at the start would take quadratic
 * time.
 *
 * Removals are passed on right away. Additions are collected and passed on
 * once per main loop iteration, as changes that only cover the rows that
 * differ. A reload of the store (clear, then add every task) therefore
 * creates at most `limit` rows instead of one row per task in the store.
 */
class GOFI.TXT.RecentTasksModel : Object, DragListModel {
    private TaskStore store;
    // What has been passed on to the widget so far
    private GenericArray<Object> shown;
    private uint update_id = 0;

    /**
     * Maximum number of tasks shown, the newest ones. uint.MAX shows all.
     */
    public uint limit {
        get {
            return _limit;
        }
        set {
            _limit = value;
            update_now ();
        }
    }
    private uint _limit;

    /**
     * Number of tasks in the store that are not shown.
     */
    public uint n_hidden {
        get {
            return store.get_n_items () - shown.length;
        }
    }

    /**
     * Emitted after the shown tasks or the number of hidden tasks changed.
     */
    public signal void changed ();

    public RecentTasksModel (TaskStore store, uint limit) {
        this.store = store;
        this._limit = limit;
        shown = new GenericArray<Object> ();
        fill (shown);
        store.items_changed.connect (on_store_items_changed);
    }

    ~RecentTasksModel () {
        if (update_id != 0) {
            Source.remove (update_id);
        }
    }

    private void fill (GenericArray<Object> items) {
        uint n = store.get_n_items ();
        uint start = n > _limit ? n - _limit : 0;
        for (uint i = n; i > start; i--) {
            items.add (store.get_item (i - 1));
        }
    }

    private void on_store_items_changed (uint position, uint removed, uint added) {
        if (removed > 0) {
            // A row of a task that is removed may already be on its way out
            // (TaskRow destroys itself when its task is (un)checked), so the
            // widget has to learn about removals right away, as it would with
            // the store itself.
            update_now ();
        } else {
            queue_update ();
        }
    }

    private void queue_update () {
        if (update_id == 0) {
            update_id = Idle.add_full (Priority.HIGH_IDLE, () => {
                update_id = 0;
                update_now ();
                return Source.REMOVE;
            });
        }
    }

    /**
     * Passes on the difference between the shown tasks and the current
     * last `limit` tasks of the store: one change per run of removed tasks,
     * then one per run of added tasks. The tasks that stay keep their order,
     * so only the rows that really differ are recreated.
     */
    private void update_now () {
        if (update_id != 0) {
            Source.remove (update_id);
            update_id = 0;
        }
        var new_shown = new GenericArray<Object> ();
        fill (new_shown);

        var in_new = new HashTable<Object, bool> (direct_hash, direct_equal);
        foreach (var item in new_shown.data) {
            in_new[item] = true;
        }
        var in_old = new HashTable<Object, bool> (direct_hash, direct_equal);
        foreach (var item in shown.data) {
            in_old[item] = true;
        }

        // Removals, from the end so that earlier positions stay valid
        uint i = shown.length;
        while (i > 0) {
            if (in_new.contains (shown[i - 1])) {
                i--;
                continue;
            }
            uint end = i;
            while (i > 0 && !in_new.contains (shown[i - 1])) {
                i--;
            }
            shown.remove_range (i, end - i);
            items_changed (i, end - i, 0);
        }

        // Additions, from the start
        uint pos = 0;
        while (pos < new_shown.length) {
            if (in_old.contains (new_shown[pos])) {
                pos++;
                continue;
            }
            uint start = pos;
            while (pos < new_shown.length && !in_old.contains (new_shown[pos])) {
                shown.insert ((int) pos, new_shown[pos]);
                pos++;
            }
            items_changed (start, 0, pos - start);
        }

        // The tasks that stayed should be in the same order; if not, start over
        bool same = shown.length == new_shown.length;
        for (uint k = 0; same && k < shown.length; k++) {
            same = shown[k] == new_shown[k];
        }
        if (!same) {
            uint old_len = shown.length;
            shown = new_shown;
            items_changed (0, old_len, new_shown.length);
        }
        changed ();
    }

    public int get_position (TxtTask task) {
        for (uint i = 0; i < shown.length; i++) {
            if (shown[i] == task) {
                return (int) i;
            }
        }
        return -1;
    }

    public void move_item (uint old_position, uint new_position) {
        if (old_position == new_position) {
            return;
        }
        var item = shown[old_position];
        var target = shown[new_position];
        store.move_item (
            store.get_task_position ((TxtTask) item),
            store.get_task_position ((TxtTask) target)
        );
        shown.remove_index (old_position);
        shown.insert ((int) new_position, item);
    }

    public Object? get_item (uint position) {
        if (position >= shown.length) {
            return null;
        }
        return shown[position];
    }

    public Type get_item_type () {
        return store.get_item_type ();
    }

    public uint get_n_items () {
        return shown.length;
    }
}
