/* Copyright 2016 Go For It! developers
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

namespace GOFI {
    
    /**
     * OrderBoxModel is an interface designed to help keep the contents of an
     * OrderBox and a list in sync.
     */
    public interface OrderBoxModel : GLib.Object {
        
        /**
         * This signal is emitted whenever an item has been moved.
         * @param pos1 original position of the item
         * @param pos2 new position of the item
         * @param sync Whether or not the OrderBox needs to be updated
         */
        public signal void item_moved (int pos1, int pos2, bool sync);
        
        /**
         * This signal is emitted when an item is removed.
         * @param pos position of the removed item
         */
        public signal void item_removed (int pos);
        
        /**
         * This signal is emitted when an item is removed.
         * @param pos position of the new item
         */
        public signal void item_added (int pos);
        
        /**
         * This signal is emitted whenever an item has been moved, removed or 
         * added.
         */
        public signal void items_changed ();
        
        public signal void reset ();
        
        /**
         * This signal is emitted after the contents of this have been sorted, 
         * causing the OrderBox to sort its rows as well.
         */
        public signal void sorted ();
        
        /**
         * This signal is emitted when the sort function returned by 
         * get_sort_func () is changed. This does not cause the OrderBox to be 
         */
        public signal void sort_func_changed ();
        
        /**
         * Returns the number of items in this.
         */
        public abstract int get_n_items ();
        
        /**
         * Moves an item in this.
         * @param pos1 original position of the item
         * @param pos2 new position of the item
         * @param sync Whether or not the OrderBox needs to be updated
         */
        public abstract void move_item (int pos1, int pos2, bool sync);
        
        /**
         * Returns the item at the specified position.
         * @param pos the position of the item to fetch
         */
        public abstract GLib.Object get_item (int pos);
        
        /**
         * Returns an OrderBoxSortFunc for sorting the OrderBox, or null.
         * Sorting rows with this function must place the rows in the same order
         * as the items in this.
         */
        public abstract OrderBoxSortFunc? get_sort_func ();
        
    }
    
    /**
     * Function used to generate rows from the Objets returned by get_item of
     * OrderBoxModel.
     */
    public delegate Gtk.Widget OrderBoxCreateWidgetFunc (Object item);
    
    /**
     * A function for comparing rows so an OrderBox's contents can be sorted.
     * @param row1 the first row
     * @param row2 the second row
     * @return a negative value if row1 should be before row2, 0 if the two rows
     * are the same or completely indistinguishable and it is guaranteed that 
     * that will stay that way, and otherwise a positive value.
     */
    public delegate int OrderBoxSortFunc (OrderBoxRow row1, OrderBoxRow row2);
    
    /**
     * Will be called whenever the row changes or is added and lets you control 
     * if the row should be visible or not.
     * @param row a row that may be filtered using this function.
     * @return true if the row should be visible and false otherwise.
     */
    public delegate bool OrderBoxFilterFunc (OrderBoxRow row);
    
    /**
     * Convienence function for checking if a selection should be extended, or 
     * replaced with a new selection.
     * Taken from gtklistbox.c
     */
    internal void get_current_selection_modifiers (Gtk.Widget widget,
                                                   out bool modify,
                                                   out bool extend)
    {
        Gdk.ModifierType state = Gdk.ModifierType.SHIFT_MASK;
        Gdk.ModifierType mask;
    
        modify = false;
        extend = false;

        if (Gtk.get_current_event_state (out state)) {
            mask = widget.get_modifier_mask (Gdk.ModifierIntent.MODIFY_SELECTION);
            if ((state & mask) == mask) {
                modify = true;
            }
            mask = widget.get_modifier_mask (Gdk.ModifierIntent.EXTEND_SELECTION);
            if ((state & mask) == mask) {
                extend = true;
            }
        }
    }
    
    /**
     * Custom container based on the code of Gtk.ListBox.
     * Unlike Gtk.ListBox this container supports reordering via drag and drop.
     */
    public class OrderBox : Gtk.Container {
        private OrderBoxModel model;
        private GLib.Sequence<OrderBoxRow> children;
        
        private OrderBoxCreateWidgetFunc widget_func;
        private OrderBoxFilterFunc filter_func;
        private OrderBoxSortFunc sort_func;
        private Gtk.Adjustment _vadjustment = null;
        
        private Gtk.Widget placeholder;
        
        private bool active_row_active = false;
        private OrderBoxRow prelight_row;
        private OrderBoxRow active_row;
        private OrderBoxRow cursor_row;
        private OrderBoxRow selected_row;
        
        private int rows_visible = 0;
        
        private OrderBoxRow drag_row;
        private Gdk.Window drag_window;
        
        private bool dragging;
        private bool drag_prepared;
        
        private int drag_min_y = 0;
        private int drag_max_y = 0;
        
        private bool in_widget = false;
        private int mouse_y = 0;
        private int drag_begin_y = 0;
        private int drag_offset_y = 0;
        
        private int gap_height = 0;
        private int gap_width = 0;
        private int drag_window_x = 0;
        private int drag_window_y = 0;
        
        /* Where the row would get placed when the drag ends */
        private int gap_pos = 0;
        private int drag_row_origin = 0;
        
        private Gtk.SelectionMode _selection_mode;
        public Gtk.SelectionMode selection_mode {
            public get {
                return _selection_mode;
            }
            public set {
                if (_selection_mode != value) {
                    if (_selection_mode == Gtk.SelectionMode.MULTIPLE) {
                        if (selected_row != null) {
                            unselect_all_internal ();
                            selected_row = null;
                        }
                    } else if (value == Gtk.SelectionMode.NONE) {
                        if (selected_row != null) {
                            selected_row.set_selected (false);
                            selected_row = null;
                        }
                    }
                    _selection_mode = value;
                }
            }
        }
        
        public Gtk.Adjustment? vadjustment {
            public get {
                return _vadjustment;
            }
            public set {
                _vadjustment = value;
            }
        }
        
        /*
         * Signals
         *--------------------------------------------------------------------*/
        
        /**
         * The row_activated signal is emitted when the user activates a row.
         */
        public virtual signal void row_activated (OrderBoxRow row) {
            
        }
        
        /**
         * The row_selected signal is emitted whenever the user selects a new 
         * row, or whenever the selection is cleared, in that case row will be 
         * null.
         */
        public virtual signal void row_selected (OrderBoxRow? row) {
            
        }
        
        /**
         * The selected_rows_changed signal is emitted when the selection is 
         * changed.
         */
        public virtual signal void selected_rows_changed () {
             
        }
        
        /**
         * This signal is emitted whenever the selection is changed.
         */
        public virtual signal void single_row_selected (OrderBoxRow row) {
            
        }
        
        /**
         * Activates the cursor row.
         */
        public virtual signal void activate_cursor_row () {
            selected_row.activate ();
        }
        
        /**
         * Moves the cursor up or down.
         */
        [Signal (action=true)]
        public virtual signal void move_cursor (Gtk.MovementStep step, 
                                                int count)
        {
            bool forward;
            OrderBoxRow prev, next;
            OrderBoxRow row = null;
            
            if (count == 0) {
                return;
            }
            
            forward = (count > 0);
            
            if (cursor_row == null) {
                cursor_row = get_first_visible ();
            }
            
            if (step == Gtk.MovementStep.DISPLAY_LINES) {
                if (cursor_row != null) {
                    
                    prev = cursor_row;
                    
                    for (int i = count.abs (); i > 0; i--) {
                        if (forward) {
                            row = get_next_visible (prev.iter);
                        } else {
                            row = get_previous_visible (prev.iter);
                        }
                        
                        if (row != null) {
                            prev = row;
                        } else {
                            row = prev;
                            break;
                        }
                    }
                    
                }
            } else if (step == Gtk.MovementStep.PAGES) {
                int page_size = 100;
                if (_vadjustment != null) {
                    page_size = (int) _vadjustment.get_page_increment ();
                }
                
                if (cursor_row != null) {
                    int start_y = cursor_row.y;
                    
                    row = cursor_row;
                    if (count < 0) {
                        /* Up */
                        while (!row.iter.is_begin ()) {
                            prev = get_previous_visible (row.iter);
                            if (prev == null) {
                                break;
                            }
                            
                            if (prev.y < start_y - page_size) {
                                break;
                            }
                            
                            row = prev;
                        }
                    } else {
                        /* Down */
                        while (!row.iter.is_end ()) {
                            next = get_next_visible (row.iter);
                            if (next == null) {
                                break;
                            }
                            
                            if (next.y > start_y + page_size) {
                                break;
                            }
                            
                            row = next;
                        }
                    }
                }
            } else if (step == Gtk.MovementStep.BUFFER_ENDS) {
                if (forward) {
                    row = get_last_visible ();
                } else {
                    row = get_first_visible ();
                }
            }
            if (row == null || row == cursor_row) {
                Gtk.DirectionType direction;
                if (forward) {
                    direction = Gtk.DirectionType.DOWN;
                } else {
                    direction = Gtk.DirectionType.UP;
                }
                
                if (!keynav_failed (direction)) {
                    Gtk.Widget toplevel_widget = this.get_toplevel ();
                    if (toplevel_widget != null) {
                        if (direction == Gtk.DirectionType.UP) {
                            direction = Gtk.DirectionType.TAB_BACKWARD;
                        } else {
                            direction = Gtk.DirectionType.TAB_FORWARD;
                        }
                        toplevel_widget.child_focus (direction);
                    }
                }
                return;
            }
            
            set_cursor_row (row);
        }
        
        /**
         * Toggles the selection of the cursor row, if possible.
         * If the row is not currently selected it will also get activated.
         */
        [Signal (action=true)]
        public virtual signal void toggle_cursor_row () {
            if (cursor_row == null){
                return;
            }
            
            if ((selection_mode == Gtk.SelectionMode.SINGLE || 
                 selection_mode == Gtk.SelectionMode.MULTIPLE) &&
                cursor_row.selected)
            {
                unselect_row (cursor_row);
            } else {
                select_and_activate (cursor_row);
            }
        }
        
        /**
         * Selects all selectable rows.
         */
        [Signal (action=true)]        
        public virtual signal void select_all () {
            if (selection_mode == Gtk.SelectionMode.MULTIPLE) {
                if (children.get_length () > 0) {
                    select_all_between (null, null, false);
                    selected_rows_changed ();
                }
            }
        }
        
        /**
         * Clears the selection.
         */
        [Signal (action=true)]
        public virtual signal void unselect_all () {
            bool dirty = false;

            if (selection_mode == Gtk.SelectionMode.BROWSE) {
                return;
            }
            
            if (selection_mode == Gtk.SelectionMode.SINGLE) {
                if (selected_row != null) {
                    selected_row.set_selected (false);
                    dirty = true;
                }
            } else {
                dirty = unselect_all_internal ();
            }
            
            if (dirty) {
                row_selected (null);
                selected_rows_changed ();
            }
        }
        
        public OrderBox () {
            base.can_focus = true;
            base.set_has_window (true);
            base.set_redraw_on_allocate (true);

            this.children = new GLib.Sequence<OrderBoxRow> ();
            dragging = false;
            drag_prepared = false;
            Gtk.StyleContext context = this.get_style_context ();
            context.add_class (Gtk.STYLE_CLASS_LIST);
            
            _selection_mode = Gtk.SelectionMode.SINGLE;
        }
        
        /**
         * Keybindings shouldn't be registered more than once, else the actions
         * will be executed multiple times.
         */
        static construct {
            unowned Gtk.BindingSet binding_set = Gtk.BindingSet.by_class (
                (ObjectClass) (typeof (OrderBox)).class_ref ()
            );
            
            // moving the cursor
            add_move_binding (
                binding_set, Gdk.Key.Up, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.DISPLAY_LINES, -1
            );
            add_move_binding (
                binding_set, Gdk.Key.KP_Up, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.DISPLAY_LINES, -1
            );
            add_move_binding (
                binding_set, Gdk.Key.Down, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.DISPLAY_LINES, 1
            );
            add_move_binding (
                binding_set, Gdk.Key.KP_Down, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.DISPLAY_LINES, 1
            );
            
            add_move_binding (
                binding_set, Gdk.Key.Home, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.BUFFER_ENDS, -1
            );
            add_move_binding (
                binding_set, Gdk.Key.KP_Home, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.BUFFER_ENDS, -1
            );
            add_move_binding (
                binding_set, Gdk.Key.End, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.BUFFER_ENDS, 1
            );
            add_move_binding (
                binding_set, Gdk.Key.KP_End, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.BUFFER_ENDS, 1
            );
            
            add_move_binding (
                binding_set, Gdk.Key.Page_Up, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.PAGES, -1
            );
            add_move_binding (
                binding_set, Gdk.Key.KP_Page_Up, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.PAGES, -1
            );
            add_move_binding (
                binding_set, Gdk.Key.Page_Down, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.PAGES, 1
            );
            add_move_binding (
                binding_set, Gdk.Key.KP_Page_Down, (Gdk.ModifierType) 0, 
                Gtk.MovementStep.PAGES, 1
            );
            
            // toggling the cursor row
            Gtk.BindingEntry.add_signal (
                binding_set, Gdk.Key.space, Gdk.ModifierType.CONTROL_MASK,
                "toggle-cursor-row", 0, null
            );
            Gtk.BindingEntry.add_signal (
                binding_set, Gdk.Key.KP_Space, Gdk.ModifierType.CONTROL_MASK,
                "toggle-cursor-row", 0, null
            );
            
            // (un)selecting all
            Gtk.BindingEntry.add_signal (
                binding_set, Gdk.Key.a, Gdk.ModifierType.CONTROL_MASK,
                "select-all", 0, null
            );
            Gtk.BindingEntry.add_signal (
                binding_set, Gdk.Key.a, 
                Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK,
                "unselect-all", 0, null
            );
        }
        
        public override void destroy () {
            this.model = null;
            this._vadjustment = null;
            base.destroy ();
        }
        
        /*
         * Drawing and allocating
         *--------------------------------------------------------------------*/
        
        /**
         * @see Gtk.Widget.realize
         */
        public override void realize () {
            Gtk.Allocation allocation;
            Gdk.WindowAttr attributes = Gdk.WindowAttr ();
            Gdk.WindowAttributesType attributes_mask;
            Gdk.Window window;
            
            this.get_allocation (out allocation);
            this.set_realized (true);
            
            attributes.x = allocation.x;
            attributes.y = allocation.y;
            attributes.width = allocation.width;
            attributes.height = allocation.height;
            attributes.window_type = Gdk.WindowType.CHILD;
                                     
            attributes.event_mask = (Gdk.EventMask.ENTER_NOTIFY_MASK | 
                                     Gdk.EventMask.LEAVE_NOTIFY_MASK | 
                                     Gdk.EventMask.POINTER_MOTION_MASK | 
                                     Gdk.EventMask.EXPOSURE_MASK | 
                                     Gdk.EventMask.BUTTON_PRESS_MASK |
                                     Gdk.EventMask.BUTTON_RELEASE_MASK);
            attributes.wclass = Gdk.WindowWindowClass.INPUT_OUTPUT;
            
            attributes_mask = Gdk.WindowAttributesType.X | 
                              Gdk.WindowAttributesType.Y;
            
            window = new Gdk.Window (
                this.get_parent_window (), attributes, attributes_mask
            );
            this.get_style_context ().set_background (window);
            window.set_user_data (this);
            this.set_window (window);
        }
        
        /**
         * {@inheritDoc}
         */
        public override bool draw (Cairo.Context cr) {
            Gtk.Allocation allocation;
            this.get_allocation (out allocation);
            Gtk.StyleContext context = this.get_style_context ();
            context.render_background (
                cr, 0, 0, allocation.width, allocation.height
            );
            
            base.draw (cr);
            return false;
        }
        
        /**
         * Adds child to a separate window in order to be able to move it 
         * around.
         */
        private void show_drag_window (OrderBoxRow child, Gdk.Device device) {
            if (drag_window == null) {
                Gdk.WindowAttr attributes = Gdk.WindowAttr ();
                Gdk.WindowAttributesType attributes_mask;
                Gdk.RGBA background = {255, 255, 255, 255};
                
                Gtk.Allocation allocation;
                child.get_allocation (out allocation);
                
                attributes.x = allocation.x;
                attributes.y = allocation.y;
                attributes.width = allocation.width;
                attributes.height = allocation.height;
                attributes.window_type = Gdk.WindowType.CHILD;
                attributes.wclass = Gdk.WindowWindowClass.INPUT_OUTPUT;
                attributes.visual = this.get_visual ();
                attributes.event_mask = Gdk.EventMask.VISIBILITY_NOTIFY_MASK | 
                                        Gdk.EventMask.EXPOSURE_MASK | 
                                        Gdk.EventMask.POINTER_MOTION_MASK;
                attributes_mask = Gdk.WindowAttributesType.X | 
                                  Gdk.WindowAttributesType.Y | 
                                  Gdk.WindowAttributesType.VISUAL;
                
                drag_window = new Gdk.Window (this.get_window (),
                                              attributes,
                                              attributes_mask);
                
                this.register_window (drag_window);
                drag_window.set_background_rgba (background); 
            }
            child.unparent ();
            child.set_parent_window (drag_window);
            child.set_parent (this);
            
            drag_window.show ();
            
            // Pass all events to this window until it is hidden or destroyed
            device.grab (drag_window, Gdk.GrabOwnership.WINDOW, false, 
                         Gdk.EventMask.POINTER_MOTION_MASK | 
                         Gdk.EventMask.BUTTON_RELEASE_MASK,
                         null, Gdk.CURRENT_TIME);
        }
        
        /** 
         * Gives drag_row the same parent window as the other rows and hides 
         * drag_window.
         */
        private void hide_drag_window () {
            if (drag_row.get_window () != this.get_window ())
            {
                drag_row.unparent ();
                drag_row.set_parent (this);
             }

            if (drag_window != null && drag_window.is_visible ()) {
                drag_window.hide ();
            }
        }
        
        public override Gtk.SizeRequestMode get_request_mode () {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }
        
        public override void size_allocate (Gtk.Allocation allocation) {
            base.set_allocation (allocation);
            Gdk.Window window = this.get_window ();
            if (window != null){
                window.move_resize (
                    allocation.x, allocation.y, 
                    allocation.width, allocation.height
                );
            }
            
            allocate_rows ();
        }
        
        private void allocate_rows () {
            Gtk.Allocation allocation;
            this.get_allocation (out allocation);
            
            Gtk.Allocation child_allocation = Gtk.Allocation ();
            
            child_allocation.x = 0;
            child_allocation.y = 0;
            child_allocation.width = allocation.width;
            child_allocation.height = 0;
            
            int child_min = 0;
            bool gap_placed = false;
            gap_pos = 0;
            
            if (placeholder != null && placeholder.visible) {
                placeholder.get_preferred_height_for_width (
                    allocation.width, out child_min, null
                );
                child_allocation.height = allocation.height;
                placeholder.size_allocate (child_allocation);
                return;
            }
            
            GLib.SequenceIter<OrderBoxRow> iter = children.get_begin_iter ();
            if (dragging) {
                allocate_drag_row (allocation.width);
                for (; !iter.is_end (); iter = iter.next ()) {
                    OrderBoxRow row = iter.get ();
                    if (row == drag_row) {
                        continue;
                    }
                    
                    if (!row.priv_visible) {
                        if (!gap_placed) {
                            gap_pos++;
                        }
                        continue;
                    }
                    
                    row.get_preferred_height_for_width (
                        allocation.width, out child_min, null
                    );
                    
                    if (!gap_placed) {
                        if (child_allocation.y + child_min/2 <= drag_window_y) {
                            gap_pos++;
                        } else {
                            child_allocation.y += gap_height;
                            gap_placed = true;
                        }
                    }
                    
                    row.y = child_allocation.y;
                    
                    child_allocation.height = child_min;
                    row.size_allocate (child_allocation);
                    child_allocation.y += child_min;
                }
            } else {
                for (; !iter.is_end (); iter = iter.next ()) {
                    OrderBoxRow row = iter.get ();
                    if (!row.get_visible()) {
                        continue;
                    }
                    
                    row.y = child_allocation.y;
                    
                    row.get_preferred_height_for_width (
                        allocation.width, out child_min, null
                    );
                    child_allocation.height = child_min;
                    row.size_allocate (child_allocation);
                    child_allocation.y += child_min;
                }
            }
            
            drag_max_y = allocation.height - gap_height;
        }
        
        /**
         * Allocates the size of drag_row and moves the drag_window.
         */
        private void allocate_drag_row (int width) {
            Gtk.Allocation row_allocation = Gtk.Allocation ();
            
            drag_row.get_preferred_height_for_width (
                width, out gap_height, null
            );
            gap_width = width;
            
            row_allocation.x = 0;
            row_allocation.y = 0;
            row_allocation.width = width;
            row_allocation.height = gap_height;
            
            drag_row.size_allocate (row_allocation);
            
            drag_window.move_resize (
                drag_window_x, drag_window_y, gap_width, gap_height
            );
        }
        
        public override void get_preferred_height (out int minimum_height,
                                                   out int natural_height)
        {
            base.get_preferred_height (out minimum_height, out natural_height);
            int min_width, natural_width;
            
            preferred_width_internal (out min_width, out natural_width);
            preferred_height_for_width_internal(
                natural_width, out minimum_height, out natural_height
            );
        }
        
        /**
         * get_preferred_* should not call get_preferred_height_for_width
         */
        private void preferred_height_for_width_internal (int width,
                                                          out int minimum_height,
                                                          out int natural_height)
        {
            int _minimum_height = 0;
            
            if (placeholder != null && placeholder.visible) {
                placeholder.get_preferred_height_for_width (
                    width, out minimum_height, null
                );
                
                natural_height = minimum_height;
                
                return;
            }
            
            GLib.SequenceIter<OrderBoxRow> iter = children.get_begin_iter ();
            for (; !iter.is_end (); iter = iter.next ()) {
                OrderBoxRow row = iter.get ();
	            if (row.get_visible ()) {
	                int row_minimum;
	                row.get_preferred_height_for_width (
	                    width, out row_minimum, null
	                );
	                _minimum_height += row_minimum;
	            }
            }
            
            minimum_height = _minimum_height;
            natural_height = _minimum_height;
        }
        
        public override void get_preferred_height_for_width (int width,
                                                             out int minimum_height,
                                                             out int natural_height)
        {
            preferred_height_for_width_internal (
                width, out minimum_height, out natural_height
            );
        }
        
        /**
         * get_preferred_* should not call get_preferred_width
         */
        private void preferred_width_internal (out int minimum_width, 
                                               out int natural_width)
        {
            int _minimum_width = 0, _natural_width = 0;
            
            if (placeholder != null && placeholder.visible) {
                placeholder.get_preferred_width (
                    out minimum_width, out natural_width
                );
                
                return;
            }
            
            GLib.SequenceIter<OrderBoxRow> iter = children.get_begin_iter ();
            for (; !iter.is_end (); iter = iter.next ()) {
                OrderBoxRow row = iter.get ();
	            if (row.get_visible ()) {
	                int row_minimum, row_natural;
	                row.get_preferred_width (
	                    out row_minimum, out row_natural
	                );
	                _minimum_width = int.max (row_minimum, _minimum_width);
	                _natural_width = int.max (row_natural, _natural_width);
	            }
            }
            
            minimum_width = _minimum_width;
            natural_width = _natural_width;
        }
        
        public override void get_preferred_width (out int minimum_width,
                                                  out int natural_width) 
        {
            preferred_width_internal (out minimum_width, out natural_width);
        }
        
        public override void get_preferred_width_for_height (int height, 
                                                             out int minimum_width, 
                                                             out int natural_width)
        {
            preferred_width_internal (out minimum_width, out natural_width);
        }
        
        /*
         * Input
         *--------------------------------------------------------------------*/
        
        /**
         * Convience function for adding key bindings for multiple modmasks at 
         * once.
         */
        private static void add_move_binding (Gtk.BindingSet binding_set,
                                       uint keyval,
                                       Gdk.ModifierType modmask,
                                       Gtk.MovementStep step,
                                       int  count)
        {
            Gdk.ModifierType extend_mod_mask = Gdk.ModifierType.SHIFT_MASK;
            Gdk.ModifierType modify_mod_mask = Gdk.ModifierType.CONTROL_MASK;

            unowned Gdk.Display? display = Gdk.Display.get_default();
            if (display != null) {
                var keymap = Gdk.Keymap.get_for_display (display);
                extend_mod_mask = keymap.get_modifier_mask(
                    Gdk.ModifierIntent.EXTEND_SELECTION
                );
                modify_mod_mask = keymap.get_modifier_mask(
                    Gdk.ModifierIntent.MODIFY_SELECTION
                );
            }
            
            Gtk.BindingEntry.add_signal (
                binding_set, keyval, modmask,
                "move_cursor", 2, typeof(Gtk.MovementStep), step, typeof(int),
                count, null
            );
            Gtk.BindingEntry.add_signal (
                binding_set, keyval, modmask | extend_mod_mask,
                "move_cursor", 2, typeof(Gtk.MovementStep), step, typeof(int),
                count, null
            );
            Gtk.BindingEntry.add_signal (
                binding_set, keyval, modmask | modify_mod_mask,
                "move_cursor", 2, typeof(Gtk.MovementStep), step, typeof(int),
                count, null
            );
            Gtk.BindingEntry.add_signal (
                binding_set, keyval, modmask | extend_mod_mask | modify_mod_mask,
                "move_cursor", 2, typeof(Gtk.MovementStep), step, typeof(int),
                count, null
            );
        }
        
        /**
         * Checks if we should start dragging.
         */
        private bool check_offset () {
            int offset = 10;
            return ((drag_window_y - drag_begin_y).abs () >= offset);
        }
        
        public override bool button_press_event (Gdk.EventButton event) {
            OrderBoxRow row;
            int y;
            
            if (children != null) {
                if (event.type == Gdk.EventType.BUTTON_PRESS || 
                    event.type == Gdk.EventType.2BUTTON_PRESS) {
                    if (!get_widget_y (event, out y)) {
                        return false;
                    }
                    if (event.button != Gdk.BUTTON_PRIMARY) {
                        return false;
                    }
                    if ((row = get_row_at_y (y)) != null) {
                        if (row.is_sensitive ()) {
                            active_row = row;
                            active_row_active = true;
                            active_row.set_state_flags (
                                Gtk.StateFlags.ACTIVE, false
                            );
                            cursor_row = row;
                            queue_draw ();
                            if (event.type == Gdk.EventType.2BUTTON_PRESS) {
                                activate_row (row);
                            } else {
                                mouse_y = y;
                                prepare_drag (row);
                            }
                        }
                    }
                    return true;
                }
            }
            return false;
        }
        
        private void prepare_drag (OrderBoxRow row) {
            Gtk.Allocation allocation;
            row.get_allocation (out allocation);
            gap_height = allocation.height;
            gap_width = allocation.width;
            drag_offset_y = mouse_y - allocation.y;
            drag_begin_y = mouse_y - drag_offset_y;
            drag_window_y = drag_begin_y;
            drag_row = row;
            drag_row_origin = row.iter.get_position ();
            drag_prepared = true;
        }
        
        public override bool button_release_event (Gdk.EventButton event) {
            if (event.button == Gdk.BUTTON_PRIMARY) {
                if (dragging) {
                    move_row (drag_row, drag_row_origin, gap_pos);
                    hide_drag_window ();
                    update_cursor (drag_row);
                    drag_row = null;
                    dragging = false;
                }
                drag_prepared = false;
                if (active_row != null && active_row_active) {
                    bool modify, extend;
                    
                    active_row.unset_state_flags (Gtk.StateFlags.ACTIVE);
                    
                    get_current_selection_modifiers (this, out modify, out extend);
                    
                    if (event.get_device ().get_source () == Gdk.InputSource.TOUCHSCREEN) {
                        modify = !modify;
                    }
                    
                    update_selection(active_row, modify, extend);
                }
                
                active_row = null;
                active_row_active = false;
                queue_draw ();
            }
            
            return true;
        }
        
        public override bool enter_notify_event (Gdk.EventCrossing event) {
            OrderBoxRow row;
            
            if (event.window != this.get_window ()) {
                return false;
            }
            
            in_widget = true;
            
            row = get_row_at_y ((int) event.y);
            update_prelight (row);
            update_active (row);
            
            return false;
        }
        
        public override bool leave_notify_event (Gdk.EventCrossing event) {
            OrderBoxRow row;
            
            if (event.window != this.get_window ()) {
                return false;
            }
            
            if (event.detail != Gdk.NotifyType.INFERIOR) {
                in_widget = false;
                row = null;
            } else {
                row = get_row_at_y ((int) event.y);
            }
            
            update_prelight (row);
            update_active (row);
            
            return false;
        }
        
        public override bool motion_notify_event (Gdk.EventMotion event) {
            int x_win, y_win, y_mouse_temp;
            
            if (!drag_prepared) {
                if (in_widget) {
                    int relative_y;
                    get_widget_y (event, out relative_y);
                    OrderBoxRow row = get_row_at_y (relative_y);
                    update_prelight (row);
                    update_active (row);
                }
                return false;
            }
            
            this.get_window ().get_origin (out x_win, out y_win);
            y_mouse_temp = (int) event.y_root - y_win;
            if (this.mouse_y != y_mouse_temp) {
                this.mouse_y = y_mouse_temp;
            
                drag_window_y = mouse_y - drag_offset_y;
                drag_window_y = int.max (drag_window_y, drag_min_y);
                drag_window_y = int.min (drag_window_y, drag_max_y);
                if (!dragging && drag_prepared && check_offset ()) {
                    dragging = true;
                    update_selection (drag_row, false, false);
                    show_drag_window (drag_row, event.device);
                }
                if (dragging) {
                    allocate_rows ();
                }
            }
            return true;
        }
        
        /**
         * Gets the y position of the event relative to this.
         */
        private bool get_widget_y (Gdk.Event event, out int y) {
            Gdk.Window window = event.get_window ();
            double ty;
            
            y = -1;
            
            if (!event.get_coords (null, out ty)) {
                return false;
            }
            
            while (window != null && window != this.get_window ()) {
                int window_y;
                window.get_position (null, out window_y);
                ty += window_y;
                
                window = window.get_parent ();
            }
            
            if (window != null) {
                y = (int) ty;
                
                return true;
            } else {
                return false;
            }
        }
        
        /*
         * Selection and row manipulation
         *--------------------------------------------------------------------*/
        
        private void set_cursor_row (OrderBoxRow row) {
            bool modify, extend;
            cursor_row = row;
            
            get_current_selection_modifiers (this, out modify, out extend);
            update_cursor (row);
            if (!modify) {
                update_selection (row, false, extend);
            }
        }
        
        private void activate_row (OrderBoxRow row) {
            if (row != null) {
                row_activated (row);
            }
        }
        
        internal void update_cursor (OrderBoxRow row) {
            ensure_row_visible (row);
            row.grab_focus ();
            row.queue_draw ();
        }
        
        private void update_prelight (OrderBoxRow? row) {
            if (row != prelight_row) {
                if (prelight_row != null) {
                    prelight_row.unset_state_flags (Gtk.StateFlags.PRELIGHT);
                }
                
                if (row != null && row.is_sensitive ()) {
                    prelight_row = row;
                    prelight_row.set_state_flags (Gtk.StateFlags.PRELIGHT, false);
                } else {
                    prelight_row = null;
                }
                
                queue_draw ();
            }
        }
        
        private void update_active (OrderBoxRow? row) {
            bool val = active_row == row;
            if (active_row != null && val != active_row_active) {
                active_row_active = val;
                if (active_row_active) {
                    active_row.set_state_flags (Gtk.StateFlags.ACTIVE, false);
                } else {
                    active_row.unset_state_flags (Gtk.StateFlags.ACTIVE);
                }
                queue_draw ();
            }
        }
        
        private void ensure_row_visible (OrderBoxRow row) {
            Gtk.Allocation allocation;
            
            if (_vadjustment == null) {
                return;
            }
            
            row.get_allocation (out allocation);
            _vadjustment.clamp_page (allocation.y, allocation.y + allocation.height);
        }
        
        private bool unselect_all_internal () {
            GLib.SequenceIter<OrderBoxRow> iter = children.get_begin_iter ();
            bool was_selected = false;
            for (; !iter.is_end (); iter = iter.next ()) {
                OrderBoxRow row = iter.get ();
                was_selected |= row.set_selected (false);
            }
            return was_selected;
        }
        
        private bool unselect_single_internal () {
            if (selected_row != null) {
                selected_row.set_selected (false);
                return true;
            }
            return false;
        }
        
        internal void update_selection (OrderBoxRow row, bool modify, 
                                        bool extend) {
            update_cursor (row);
            
            if (!row.selectable) {
                return;
            }
            
            switch (_selection_mode) {
                case Gtk.SelectionMode.NONE:
                    return;
                case Gtk.SelectionMode.BROWSE:
                    unselect_single_internal ();
                    selected_row = row;
                    row_selected (selected_row);
                    single_row_selected (row);
                    break;
                case Gtk.SelectionMode.SINGLE:
                    unselect_single_internal ();
                    
                    if (row.set_selected (modify ? !row.selected : true)) {
                        this.selected_row = row;
                        single_row_selected (row);
                    } else {
                        this.selected_row = null;
                    }
                    row_selected (selected_row);
                    break;
                default: /* Gtk.SelectionMode.MULTIPLE */
                    if (extend) {
                        unselect_all_internal ();
                        if (selected_row == null) {
                            row.set_selected (true);
                            this.selected_row = row;
                            row_selected (row);
                        } else {
                            select_all_between (selected_row, row, false);
                        }
                    } else if (modify) {
                        row.set_selected (!row.selected);
                        row_selected (row);
                    } else {
                        unselect_all_internal ();
                        row.set_selected (!row.selected);
                        this.selected_row = row;
                        row_selected (row);
                        single_row_selected (row);
                    }
                    break;
            }
            
            selected_rows_changed ();
        }
        
        /**
         * Selects all rows between row1, and row2, row1 and row2 included.
         */
        private void select_all_between (OrderBoxRow? row1, OrderBoxRow? row2, 
                                         bool modify) {
            OrderBoxRow first_row;
            int rows, pos1, pos2;
            
            if (row1 == null) {
                GLib.SequenceIter<OrderBoxRow> iter = children.get_begin_iter ();
                row1 = iter.get ();
            }
            if (row2 == null) {
                GLib.SequenceIter<OrderBoxRow> iter = children.get_end_iter ();
                if (iter.is_begin ()) {
                    return;
                } else {
                    iter = iter.prev ();
                }
                row2 = iter.get ();
            }
            if (row1 == null || row2 == null) {
                return;
            }
            pos1 = row1.iter.get_position ();
            pos2 = row2.iter.get_position ();
            
            if (pos1 > pos2) {
                rows = pos1 - pos2;
                first_row = row2;
            } else {
                rows = pos2 - pos1;
                first_row = row1;
            }
            rows++; // include the last row
            GLib.SequenceIter<OrderBoxRow> iter = first_row.iter;
            for (int i = rows; i > 0 && !iter.is_end (); i--) {
                OrderBoxRow row = iter.get ();
                if (row.priv_visible) {
                    if (modify) {
                        row.set_selected (!row.selected);
                    } else {
                        row.set_selected (true);
                    }
                }
                iter = iter.next ();
            }
        }
        
        internal void select_and_activate (OrderBoxRow row) {
            select_row_internal (row);
            update_cursor (row);
            activate_row (row);
        }
        
        private void select_row_internal (OrderBoxRow row) {
            if (!row.selectable || row.selected) {
                return;
            }
            
            if (_selection_mode == Gtk.SelectionMode.NONE) {
                return;
            }
            if (_selection_mode != Gtk.SelectionMode.MULTIPLE) {
                unselect_single_internal ();
            }
            
            row.set_selected (true);
            selected_row = row;
            
            row_selected (row);
            selected_rows_changed ();
        }
        
        public void select_row (OrderBoxRow? row) {
            bool modified = false;
            if (row != null) {
                select_row_internal (row);
            } else {
                if (_selection_mode == Gtk.SelectionMode.MULTIPLE) {
                    modified = unselect_all_internal ();
                } else {
                    modified = unselect_single_internal ();
                }
                if (modified) {
                    row_selected (null);
                    selected_rows_changed ();
                }
            }
        }
        
        public void unselect_row (OrderBoxRow row) {
            if (_selection_mode == Gtk.SelectionMode.SINGLE || !row.selected) {
                return;
            }
            
            if (selected_row == row) {
                selected_row = null;
            }
            
            row.set_selected (false);
            
            row_selected (null);
            selected_rows_changed ();
        }
        
        /*
         * Misc
         *--------------------------------------------------------------------*/
        
        private unowned OrderBoxRow? get_first_visible () {
            SequenceIter<OrderBoxRow> iter = children.get_begin_iter ();
            unowned OrderBoxRow row = null;
            
            if (!iter.is_end ()) {
                row = children.get_begin_iter ().get ();
            }
            if (row != null && !row.is_visible ()) {
                row = get_next_visible (row.iter);
            }
            if (row != null) {
                return row;
            }
            return null;
        }
        
        private unowned OrderBoxRow? get_last_visible () {
            var iter = children.get_end_iter ();
            if (iter.is_begin ()) {
                return null;
            } else {
                iter = iter.prev ();
            }
            unowned OrderBoxRow row = iter.get ();
            if (row != null && !row.is_visible ()) {
                row = get_previous_visible (row.iter);
            }
            return row;
        }
        
        private void move_row (OrderBoxRow child, int origin, int position) {
            if (position == origin) {
                return;
            } 
            if (position > origin) {
                position++;
            }
            child.iter.move_to (children.get_iter_at_pos (position));
            if (model != null) {
                model.move_item (origin, position, false);
            }
        }
        
        /**
         * Used to keep track of the number of visible rows.
         */
        internal void visibility_changed (OrderBoxRow row) {
            update_row_is_visible (row);
        }
        
        private void update_row_is_visible (OrderBoxRow row) {
            bool was_visible = row.priv_visible;
            
            row.priv_visible = row.get_visible () && row.get_child_visible ();
            
            if (was_visible && !row.priv_visible) {
                change_visible_rows (-1);
            } else if (!was_visible && row.priv_visible) {
                change_visible_rows (1);
            }
        }
        
        internal void got_row_changed (OrderBoxRow row) {
            apply_filter (row);
        }
        
        public override void forall_internal (bool include_internals, 
                                              Gtk.Callback callback)
        {
            GLib.SequenceIter<OrderBoxRow> iter;
            
            if (include_internals && placeholder != null) {
                callback(placeholder);
            }
            
            iter = children.get_begin_iter ();
            /* a for loop causes invalid reads here */
            while (iter != null && !iter.is_end ()) {
                OrderBoxRow row = iter.get ();
                iter = iter.next ();
                callback (row);
            }
        }
        
        private unowned OrderBoxRow? get_next_visible (
                                            GLib.SequenceIter<OrderBoxRow> iter) 
        {
            GLib.SequenceIter<OrderBoxRow> _iter;
            unowned OrderBoxRow row;
            
            if (iter.is_end ()) {
                return null;
            }
            _iter = iter.next ();
            while (!_iter.is_end ()) {
                row = _iter.get ();
                if (row != null && row.priv_visible) {
                    return row;
                }
                _iter = _iter.next ();
            }
            return null;
        }
        
        private unowned OrderBoxRow? get_previous_visible (
                                            GLib.SequenceIter<OrderBoxRow> iter)
        {
            GLib.SequenceIter<OrderBoxRow> _iter;
            unowned OrderBoxRow row;
            
            if (iter.is_begin ()) {
                return null;
            }
            _iter = iter.prev ();
            while (true) {
                row = _iter.get ();
                if (row != null && row.priv_visible) {
                    return row;
                }
                if (_iter.is_begin ()) {
                    break;
                }
                _iter = _iter.prev ();
            }
            
            return null;
        }
        
        /*
         * Model
         *--------------------------------------------------------------------*/
        
        private void connect_model_signals () {
            if (model == null) {
                return;
            }
            
            model.item_moved.connect (on_item_moved);
            model.item_removed.connect (on_item_removed);
            model.item_added.connect (on_item_added);
            model.sorted.connect (on_sorted);
            model.reset.connect (on_reset);
        }
        
        private void disconnect_model_signals () {
            if (model == null) {
                return;
            }
            
            model.item_moved.disconnect (on_item_moved);
            model.item_removed.disconnect (on_item_removed);
            model.item_added.disconnect (on_item_added);
            model.sorted.disconnect (on_sorted);
            model.reset.disconnect (on_reset);
        }
        
        private void on_item_moved (int pos1, int pos2, bool sync) {
            GLib.SequenceIter<OrderBoxRow> iter;
            
            if (!sync) {
                return;
            }
            
            iter = children.get_iter_at_pos (pos1);
            
            move_row (iter.get(), pos1, pos2);
        }
        
        private void on_item_removed (int pos) {
            GLib.SequenceIter<OrderBoxRow> iter;
            iter = children.get_iter_at_pos (pos);
            if (iter != null) {
                OrderBoxRow row = iter.get ();
                remove_internal (row);
                row.destroy ();
            }
        }
        
        private void on_item_added (int pos) {
            Gtk.Widget row = widget_func(model.get_item (pos));
            insert_internal (row, pos);
            row.show_all ();
        }
        
        private void on_sorted () {
            sort_internal ();
        }
        
        private void on_reset () {
            clear ();
            populate ();
        }
        
        /*
         * Public methods + helper functions
         *--------------------------------------------------------------------*/
        
        /**
         * Adds a widget to OrderBox unless a model is bound to this.
         * This does the same as {@link insert} (widget, -1).
         * @param the widget widget to add to this
         */
        public override void add (Gtk.Widget widget) {
            insert (widget, -1);
        }
        
        /**
         * Inserts a widget at the specified position.
         * @param widget the widget to add to this
         * @param position the position to insert the widget in
         */
        public void insert (Gtk.Widget widget, int position) {
            if (model != null) {
                warning (
                    "Adding children, when a model is bound to this is not " +
                    "supported"
                );
                return;
            }
            
            insert_internal (widget, position);
        }
        
        private void insert_internal (Gtk.Widget widget, int position) {
            GLib.SequenceIter iter;
            OrderBoxRow row = widget as OrderBoxRow;
            if (row == null) {
                row = new OrderBoxRow ();
                row.add (widget);
            }
            if (position < 0) {
                iter = children.append (row);
            } else if (position == 0) {
                iter = children.prepend (row);
            } else {
                GLib.SequenceIter<OrderBoxRow> current_iter;
                current_iter = children.get_iter_at_pos (position);
                iter = current_iter.insert_before (row);
            }
            row.iter = iter;
            row.set_parent (this);
            row.set_child_visible (true);
            
            row.priv_visible = row.get_visible ();
            apply_filter (row);
            
            if (row.priv_visible) {
                change_visible_rows (1);
            }
            
            apply_filter (row);
        }
        
        private void apply_filter (OrderBoxRow row) {
            bool show = true;
            if (filter_func != null) {
                show = filter_func (row);
            }
            row.set_child_visible (show);
            
            update_row_is_visible (row);
        }
        
        private void change_visible_rows (int change) {
            bool was_zero = rows_visible == 0;
            
            rows_visible += change;
            
            if (placeholder != null && (was_zero || rows_visible == 0)) {
                placeholder.set_visible (rows_visible == 0);
            }
        }
        
        /**
         * Removes widget from this, unless a model is bound to this.
         * @param child the widget that needs to be removed from this
         */
        public override void remove (Gtk.Widget child) {
            if (model != null) {
                warning (
                    "Removing children, when a model is bound to this is not " +
                    "supported"
                );
                return;
            }
            remove_internal (child);
        }
        
        private void remove_internal (Gtk.Widget child) {
            OrderBoxRow row = child as OrderBoxRow;
            if (row != null && row.get_parent () == this ) {
                if (row == prelight_row) {
                    row.unset_state_flags (Gtk.StateFlags.PRELIGHT);
                    prelight_row = null;
                }
                if (row == active_row) {
                    row.unset_state_flags (Gtk.StateFlags.ACTIVE);
                    active_row = null;
                }
                if (row == cursor_row) {
                    var new_cursor_row = get_next_visible (row.iter);
                    if (new_cursor_row == null) {
                        new_cursor_row = get_previous_visible (row.iter);
                    }
                    if (new_cursor_row != null) {
                        set_cursor_row (new_cursor_row);
                    } else {
                        /* No row can replace the cursor row, which means that
                           no visible, selectable row exists. */ 
                        selected_row = null;
                        row_selected (null);
                    }
                } else if (row == selected_row) {
                    selected_row = null;
                }
                row.unparent ();
                row.iter.remove ();
                if (row.priv_visible) {
                    change_visible_rows(-1);
                }
                if (this.get_visible()) {
                    this.queue_resize_no_redraw ();
                }
                return;
            }
            warning ("Tried to remove non-child %p", child);
        }
        
        public void set_placeholder (Gtk.Widget? placeholder) {
            
            if (this.placeholder != null) {
                this.placeholder.unparent ();
                this.queue_resize ();
            }
            
            this.placeholder = placeholder;
            
            if (this.placeholder != null) {
                this.placeholder.set_parent (this);
                this.placeholder.set_visible (rows_visible == 0);
            }
        }
        
        /**
         * Sorts the contents of this, if no model is bound to this.
         */
        public void sort () {
            if (model != null) {
                return;
            }
            sort_internal ();
        }
        
        private void sort_internal () {
            if (sort_func == null) {
                return;
            }
            
            children.sort ( (GLib.CompareDataFunc<GOFI.OrderBoxRow>) sort_func);
            queue_resize ();
        }
        
        /**
         * Update the filtering for all rows.
         */
        public void invalidate_filter () {
            GLib.SequenceIter<OrderBoxRow> iter = children.get_begin_iter ();
            for (; !iter.is_end (); iter = iter.next ()) {
                OrderBoxRow row = iter.get ();
                apply_filter (row);
            }
        }
        
        /**
         * By setting a filter function on the this one can decide dynamically 
         * which of the rows to show.
         */
        public void set_filter_func (owned OrderBoxFilterFunc? filter_func) {
            this.filter_func = (owned) filter_func;
            invalidate_filter ();
        }
        
        /**
         * By setting a sort function on the this one can reorder the rows of 
         * this OrderBox, based on the contents of the rows.
         */
        public void set_sort_func (owned OrderBoxSortFunc? sort_func) {
            if (model != null) {
                return;
            }
            
            this.sort_func = (owned) sort_func;
        }
        
        /**
         * Binds a model to this.
         * This will remove all current children from this.
         * @param model model to bind to this
         */
        public void bind_model (OrderBoxModel model, 
                                owned OrderBoxCreateWidgetFunc widget_func)
        {
            if (model == this.model) {
                return;
            }
            
            disconnect_model_signals();
            
            clear ();
            
            this.model = model;
            this.widget_func = (owned) widget_func;
            this.sort_func = this.model.get_sort_func();
            populate ();
            connect_model_signals ();
        }
        
        private void clear () {
            GLib.SequenceIter<OrderBoxRow> iter, next;
            iter = children.get_begin_iter ();
            while (iter != null && !iter.is_end ()) {
                OrderBoxRow row = iter.get ();
                row.unparent ();
                next = iter.next ();
                iter.remove ();
                row.destroy ();
                iter = next;
            }
        }
        
        /**
         * Adds rows from the model to this.
         */
        private void populate () {
            if (model == null) {
                return;
            }
            
            int n_items = model.get_n_items ();
            Gtk.Widget row;
            for (int i = 0; i < n_items; i++) {
                row = widget_func(model.get_item (i));
                insert_internal (row, -1);
                row.show_all ();
            }
        }
        
        /**
         * Returns the row located at the specified y position, if one exists.
         * @param y the y position of the requested row
         * @return a row if a row exists at that position, null otherwise
         */
        public unowned OrderBoxRow? get_row_at_y (int y) {
            GLib.SequenceIter<OrderBoxRow> iter;
            unowned OrderBoxRow prev, row;
            
            prev = null;
            iter = children.get_begin_iter ();
            for (; !iter.is_end (); iter = iter.next ()) {
                row = iter.get ();
                if (row.get_visible()) {
                    if (row.y < y) {
                        prev = row;
                    } else {
                        break;
                    }
                }
            }
            
            if (prev != null) {
                Gtk.Allocation allocation;
                prev.get_allocation(out allocation);
                if (prev.y + allocation.height > y) {
                    return prev;
                }
            }
            
            return null;
        }
        
        /**
         * Gets the n-th child in the list.
         */
        public unowned OrderBoxRow? get_row_at_index (int index) {
            GLib.SequenceIter<OrderBoxRow> iter;
            
            iter = children.get_iter_at_pos (index);
            if (!iter.is_end ()) {
                return iter.get ();
            }
            
            return null;
        }
        
        /**
         * Gets the n-th visibile child in the list.
         */
        public unowned OrderBoxRow? get_nth_visible (int index) {
            GLib.SequenceIter<OrderBoxRow> iter;
            unowned OrderBoxRow row = null;
            int i;
            
            iter = children.get_begin_iter ();
            for (i = -1; !iter.is_end () && i < index; iter = iter.next ()) {
                row = iter.get ();
                if (row.get_visible ()) {
                    i++;
                } 
            }
            
            if (i == index && row != null) {
                
                return row;
            }
            
            return null;
        }
        
        /**
         * Gets the selected row.
         */
        public unowned OrderBoxRow? get_selected_row () {
            return selected_row;
        }
        
        /**
         * Creates a list of all selected children.
         */
        public GLib.List<unowned OrderBoxRow> get_selected_rows () {
            GLib.List<unowned OrderBoxRow> selected;
            GLib.SequenceIter<OrderBoxRow> iter;
            unowned OrderBoxRow row;
            
            selected = new GLib.List<unowned OrderBoxRow> ();
            iter = children.get_begin_iter ();
            for (; iter.is_end (); iter = iter.next ()) {
                row = iter.get ();
                if (row.is_selected ()) {
                    selected.prepend (row);
                }
            }
            
            selected.reverse ();
            
            return selected;
        }
    }
}
