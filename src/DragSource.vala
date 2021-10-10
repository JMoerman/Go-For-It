/* Copyright 2021 Jonathan Moerman, adapted from GTK source code.
 *
 * GTK - The GIMP Toolkit
 * Copyright (C) 1995-1999 Peter Mattis, Spencer Kimball and Josh MacDonald
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Modified by the GTK+ Team and others 1997-2000.  See the AUTHORS
 * file for a list of people on the GTK+ Team.  See the ChangeLog
 * files for a list of changes.  These files are distributed with
 * GTK+ at ftp://ftp.gtk.org/pub/gtk/.
 */

namespace GOFI {

    static int drag_offset_x = 0;
    static int drag_offset_y = 0;

    [Compact]
    private class DragSourceSite {
        public Gdk.ModifierType start_button_mask;
        public Gtk.TargetList target_list;
        public Gdk.DragAction actions;

        public Gtk.GestureDrag drag_gesture;
        public Gtk.GestureLongPress press_gesture;
        public unowned Gtk.Widget widget;

        public DragSourceSite (Gtk.Widget widget) {
            this.widget = widget;
            drag_gesture = new Gtk.GestureDrag (widget);
            drag_gesture.propagation_phase = Gtk.PropagationPhase.NONE;
            drag_gesture.button = 0;

            press_gesture = new Gtk.GestureLongPress (widget);
            press_gesture.propagation_phase = Gtk.PropagationPhase.NONE;
            press_gesture.button = 0;

            drag_gesture.begin.connect (this.drag_source_gesture_begin);
            press_gesture.pressed.connect (this.on_long_press);
            widget.button_press_event.connect (this.drag_source_event_cb);
            widget.button_release_event.connect (this.drag_source_event_cb);
            widget.motion_notify_event.connect (this.drag_source_event_cb);
        }

        public void disconnect_widget (Gtk.Widget widget) {
            widget.button_press_event.disconnect (this.drag_source_event_cb);
            widget.button_release_event.disconnect (this.drag_source_event_cb);
            widget.motion_notify_event.disconnect (this.drag_source_event_cb);
        }

        private void drag_source_gesture_begin (Gtk.Gesture _gesture, Gdk.EventSequence? sequence) {
            var gesture = (Gtk.GestureSingle) _gesture;
            uint button = 1;
            if (gesture.get_current_sequence () == null) {
                button = gesture.get_current_button ();
            }

            if (start_button_mask == 0 || (start_button_mask & (Gdk.ModifierType.BUTTON1_MASK << (button - 1))) == 0) {
                gesture.set_state (Gtk.EventSequenceState.DENIED);
            }
        }

        private void on_long_press (Gtk.GestureLongPress gesture, double x, double y) {
            var sequence = press_gesture.get_current_sequence ();
            var last_event = press_gesture.get_last_event (sequence).copy ();

            var button = press_gesture.get_current_button ();
            gesture.reset ();
            drag_offset_x = (int) x;
            drag_offset_y = (int) y;

            Gtk.drag_begin_with_coordinates (widget, target_list, actions, (int) button, last_event, (int) x, (int) y);
        }

        private static bool gtk_simulates_touchscreen () {
          return (Gtk.get_debug_flags () & Gtk.DebugFlag.TOUCHSCREEN) != 0;
        }

        private bool drag_source_event_cb (Gtk.Widget widget, Gdk.Event event) {
            double start_x, start_y, offset_x, offset_y;
            var  event_source = event.get_device ().get_source ();
            if (gtk_simulates_touchscreen () || event_source == Gdk.InputSource.TOUCHSCREEN || event_source == Gdk.InputSource.PEN) {
                press_gesture.handle_event (event);
                return false;
            }

            drag_gesture.handle_event (event);

            if (drag_gesture.is_recognized ()) {
                drag_gesture.get_start_point (out start_x, out start_y);
                drag_gesture.get_offset (out offset_x, out offset_y);
                if (Gtk.drag_check_threshold (widget, (int) start_x, (int) start_y, (int) (start_x + offset_x), (int) (start_y + offset_y))) {
                    var sequence = drag_gesture.get_current_sequence ();
                    var last_event = drag_gesture.get_last_event (sequence).copy ();

                    var button = drag_gesture.get_current_button ();
                    drag_gesture.reset ();
                    drag_offset_x = (int) start_x;
                    drag_offset_y = (int) start_y;
                    Gtk.drag_begin_with_coordinates (widget, target_list, actions, (int) button, last_event, (int) start_x, (int) start_y);

                    return true;
                }
            }

            return false;
        }
    }


    /**
     * drag_source_set: (method)
     * @widget: a Gtk.Widget
     * @start_button_mask: the bitmask of buttons that can start the drag
     * @targets: the table of targets that the drag will support
     * @actions: the bitmask of possible actions for a drag from this widget
     *
     * Sets up a widget so that GTK+ will start a drag operation when the user
     * clicks and drags on the widget. The widget must have a window.
     */
    public static void drag_source_set (Gtk.Widget widget , Gdk.ModifierType start_button_mask, Gtk.TargetEntry[]? targets, Gdk.DragAction actions) {
        unowned DragSourceSite? site = widget.get_data<DragSourceSite> ("gofi-site-data");

        widget.add_events (
            widget.get_events () |
            Gdk.EventMask.BUTTON_PRESS_MASK |
            Gdk.EventMask.BUTTON_RELEASE_MASK |
            Gdk.EventMask.BUTTON_MOTION_MASK
        );

        if (site != null) {
            site.target_list = null;
        } else {
            var new_site = new DragSourceSite (widget);
            site = new_site;
            widget.set_data<DragSourceSite> ("gofi-site-data", (owned) new_site);
        }

        site.start_button_mask = start_button_mask;

        site.target_list = new Gtk.TargetList (targets);

        site.actions = actions;
    }

    /**
     * gtk_drag_source_unset: (method)
     * @widget: a #GtkWidget
     *
     * Undoes the effects of drag_source_set().
     */
    public static void drag_source_unset (Gtk.Widget widget) {
        unowned DragSourceSite? site = widget.get_data<DragSourceSite> ("gofi-site-data");

        if (site != null) {
          site.disconnect_widget (widget);
          widget.set_data ("gofi-site-data", null);
        }
    }
}
