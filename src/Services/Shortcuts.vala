/* Copyright 2019 Go For It! developers
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
 * The code in this file is based on the keybinding code from
 * https://gitlab.com/doublehourglass/dnd_order_list_box
 */
namespace GOFI {

    public class Shortcut {
        public uint key;
        public Gdk.ModifierType modifier;

        public bool is_valid {
            get {
                return key != 0;
            }
        }

        public Shortcut(uint k, Gdk.ModifierType m) {
            this.key = k;
            this.modifier = m;
        }

        public Shortcut.from_string (string accelerator) {
            Gtk.accelerator_parse(accelerator, out this.key, out this.modifier);
        }

        public Shortcut.disabled () {
            this.key = 0;
            this.modifier = 0;
        }

        public string to_string () {
            if (!this.is_valid) {
                return "";
            }
            return Gtk.accelerator_name (key, modifier);
        }

        public string to_readable () {
            if (!this.is_valid) {
                return _("disabled");
            }

            var tmp = "";

            if ((this.modifier & Gdk.ModifierType.CONTROL_MASK) != 0) {
                tmp += "Ctrl + ";
            }
            if ((this.modifier & Gdk.ModifierType.SHIFT_MASK) != 0) {
                tmp += "Shift + ";
            }
            if ((this.modifier & Gdk.ModifierType.MOD1_MASK) != 0) {
                tmp += "Alt + ";
            }
            switch (this.key) {
                case Gdk.Key.Return:
                    tmp += "Enter"; // Most keyboards have Enter printed on the key
                    break;
                default:
                    tmp += Gdk.keyval_name (this.key);
                    break;
            }

            return tmp;
        }

        public bool equals (Shortcut other) {
            return other.key == key && other.modifier == modifier;
        }
    }

    public struct KeyBindingParam<G> {
        Gtk.BindingArg arg;

        // t should be long, double, or string depending on G
        public KeyBindingParam(G p, Type t) {
            this.arg.arg_type = t;
            this.arg.string_data = (string) p; // should be large enough
        }

        public G get_param () {
            return (G) arg.string_data;
        }
    }

    public struct MoveKeyParams {
        KeyBindingParam[] params;

        MoveKeyParams(Gtk.MovementStep step, int count) {
            params = {
                KeyBindingParam<Gtk.MovementStep>(step, typeof(long)),
                KeyBindingParam<int>(count, typeof(long))
            };
        }
    }

    public struct KeyBinding {
        string shortcut_id;
        string signal_name;
        KeyBindingParam[] params;
        public KeyBinding(string sc, string s, KeyBindingParam[] p) {
            this.shortcut_id = sc;
            this.signal_name = s;
            this.params = p;
        }
    }

    public class KeyBindingSettings {
        private GLib.Settings settings_backend;
        HashTable<string, Shortcut> shortcuts;

        public struct ConfigurableShortcut {
            string shortcut_id;
            string description;

            public ConfigurableShortcut(string sc_id, string descr) {
                this.shortcut_id = sc_id;
                this.description = descr;
            }
        }

        public static ConfigurableShortcut[] known_shortcuts = {
            ConfigurableShortcut ("filter",         _("Filter tasks")),
            ConfigurableShortcut ("add-new",        _("Add new task/list")),
            ConfigurableShortcut ("toggle-timer",   _("Start/Stop the timer")),
            ConfigurableShortcut ("mark-task-done", _("Mark the task as complete")),
            ConfigurableShortcut ("move-row-up",    _("Move selected row up")),
            ConfigurableShortcut ("move-row-down",  _("Move selected row down")),

            ConfigurableShortcut ("next-task",      _("Move to next task/row")),
            ConfigurableShortcut ("prev-task",      _("Move to previous task/row")),
            ConfigurableShortcut ("cycle-page",     _("Move to right screen")),
            ConfigurableShortcut ("cycle-page-reverse", _("Move to left screen")),
        };

        static KeyBinding[] DragListBindings = {
            KeyBinding(SCK_NEXT_TASK, "move-cursor", MoveKeyParams(Gtk.MovementStep.DISPLAY_LINES, 1).params),
            KeyBinding(SCK_PREV_TASK, "move-cursor", MoveKeyParams(Gtk.MovementStep.DISPLAY_LINES, -1).params),
            KeyBinding(SCK_MOVE_ROW_UP, "move-selected-row", {KeyBindingParam<long>(1, typeof(long))}),
            KeyBinding(SCK_MOVE_ROW_DOWN, "move-selected-row", {KeyBindingParam<long>(-1, typeof(long))}),
        };

        static KeyBinding[] TaskListBindings = {
            KeyBinding(SCK_FILTER, "toggle-filtering", {}),
        };

        static KeyBinding[] WindowBindings = {
            KeyBinding(SCK_FILTER, "filter-fallback-action", {}),
        };

        static KeyBinding[] TaskListPageBindings = {
            KeyBinding(SCK_NEXT_TASK, "switch_to_next", {}),
            KeyBinding(SCK_PREV_TASK, "switch_to_prev", {}),
            KeyBinding(SCK_MARK_TASK_DONE, "mark_task_done", {}),
        };

        public KeyBindingSettings () {
            shortcuts = new HashTable<string, Shortcut> (str_hash, str_equal);

            var schema_source = GLib.SettingsSchemaSource.get_default ();
            var schema_id = GOFI.APP_ID + ".keybindings";

            var schema = schema_source.lookup (schema_id, true);
            settings_backend = new GLib.Settings.full (schema, null, null);

            if (schema != null) {
                settings_backend = new GLib.Settings.full (schema, null, null);
            } else {
                warning ("Settings schema \"%s\" is not installed on your system!", schema_id);
                return;
            }

            foreach (var key in settings_backend.list_keys ()) {
                shortcuts[key] = new Shortcut.from_string (settings_backend.get_string (key));
            }
            install_bindings_for_class (
                typeof (DragList),
                DragListBindings
            );
            install_bindings_for_class (
                typeof (TXT.TaskListWidget),
                TaskListBindings
            );
            install_bindings_for_class (
                typeof (TaskListPage),
                TaskListPageBindings
            );
            install_bindings_for_class (
                typeof (MainWindow),
                WindowBindings
            );
        }

        public Shortcut? get_shortcut (string shortcut_id) {
            return shortcuts.lookup (shortcut_id);
        }

        public string? conflicts (Shortcut sc) {
            string? conflict_id = null;

            shortcuts.foreach ((key, other) => {
                if (sc.equals (other)) {
                    conflict_id = key;
                }
            });

            return conflict_id;
        }

        /**
         * Todo: unbind old shortcut and bind the actions to the new one
         */
        public void set_shortcut (string shortcut_id, Shortcut sc) {
            var old_sc = shortcuts[shortcut_id];

            if (old_sc == null) {
                warning ("No shortcut with id \"%s\" is known", shortcut_id);
                return;
            }

            shortcuts[shortcut_id] = sc;
            settings_backend.set_string (shortcut_id, sc.to_string ());
        }

        public void install_bindings_for_class (Type type, KeyBinding[] bindings) {
            install_bindings (
                Gtk.BindingSet.by_class ((ObjectClass) (type).class_ref ()),
                bindings
            );
        }

        public void install_bindings (Gtk.BindingSet bind_set, KeyBinding[] bindings) {
            foreach (var kb in bindings) {
                var sc = get_shortcut (kb.shortcut_id);
                if (sc == null) {
                    if (settings_backend != null) {
                        warning ("Unknown shortcut id: \"%s\".", kb.shortcut_id);
                    }
                    continue;
                }
                if (!sc.is_valid) {
                    return;
                }

                var binding_args = new SList<Gtk.BindingArg?> ();

                for (int i = 0; i < kb.params.length; i++) {
                    binding_args.prepend (kb.params[i].arg);
                }

                binding_args.reverse ();

                Gtk.BindingEntry.add_signall (
                    bind_set, sc.key, sc.modifier, kb.signal_name, binding_args
                );
            }
        }
    }
}
