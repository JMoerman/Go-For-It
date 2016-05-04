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
     * A row in a OrderBox, based on the code of Gtk.ListBoxRow.
     * 
     * When a OrderBoxRow is used in an OrderBox while a model is bound to this 
     * OrderBox {@link Gtk.Widget.destroy} should not be called.
     */
    public class OrderBoxRow : Gtk.Bin {
        internal bool priv_visible;
        internal bool selected = false;
        internal int y;
        internal GLib.SequenceIter iter;
        
        private bool _activatable;
        
        /**
         * Whether this row can be activated or not.
         */
        public bool activatable {
            public get {
                return _activatable;
            }
            public set {
                if (value != _activatable) {
                    if (!value) {
                        _activatable = value;
                        
                        update_style ();
                    }
                }
            }
        }
        
        private bool _selectable;
        
        /**
         * Whether this row can be selected or not.
         */
        public bool selectable {
            public get {
                return _selectable;
            }
            public set {
                if (value != _selectable) {
                    if (!value) {
                        set_selected (false);
                        
                        _selectable = value;
                        
                        update_style ();
                    }
                }
            }
        }
        
        public OrderBoxRow () {
            Gtk.StyleContext context;
            
            this.set_can_focus (true);
            this.set_redraw_on_allocate (true);
            
            _activatable = true;
            _selectable = true;
            
            context = this.get_style_context ();
            context.add_class (Gtk.STYLE_CLASS_LIST_ROW);
            context.add_class (Gtk.STYLE_CLASS_BUTTON);
            
            priv_visible = true;
            
            this.activate_signal = Signal.lookup ("activate", typeof (OrderBoxRow));
        }
        
        private void update_style () {
            OrderBox box = get_box ();
            Gtk.StyleContext context = get_style_context ();
            bool can_select;
            
            if (box != null && box.selection_mode != Gtk.SelectionMode.NONE) {
                can_select = true;
            } else {
                can_select = false;
            }
            
            if (activatable || (selectable && can_select)) {
                context.add_class (Gtk.STYLE_CLASS_BUTTON);
            } else {
                context.remove_class (Gtk.STYLE_CLASS_BUTTON);
            }
        }
        
        internal void set_focus () {
            OrderBox box = get_box ();
            bool modify;
            bool extend;
            
            if (box == null) {
                return;
            }
            
            get_current_selection_modifiers (this, out modify, out extend);
            
            if (modify) {
                box.update_cursor (this);
            } else {
                box.update_selection (this, false, false);
            }
        }
        
        public override bool focus (Gtk.DirectionType direction) {
            Gtk.Widget child = this.get_child ();
            bool had_focus = this.has_focus;
            
            if (had_focus) {
                /* If on row, going right, enter into possible container */
                if (child != null && 
                    (direction == Gtk.DirectionType.RIGHT ||
                     direction == Gtk.DirectionType.TAB_FORWARD))
                {
                    if (child.focus (direction)) {
                        return true;
                    }
                }
                return false;
            } else if (this.get_focus_child() != null) {
                /* Child has focus, always navigate inside it first */
                if (child.focus (direction)) {
                    return true;
                }
                
                /* If exiting child container to the left, select row  */
                if (direction == Gtk.DirectionType.LEFT || 
                    direction == Gtk.DirectionType.TAB_BACKWARD)
                {
                    this.set_focus ();
                    return true;
                }
                
                return false;
            } else {
                /* If coming from the left, enter into possible container */
                if (child != null &&
                    (direction == Gtk.DirectionType.LEFT || 
                     direction == Gtk.DirectionType.TAB_BACKWARD))
                {
                    if (child.child_focus (direction)) {
                        return true;
                    }
                }
                this.set_focus ();
                return true;
            }
        }
        
        public new virtual signal void activate () {
            OrderBox box = this.get_box ();
            
            if (box != null) {
                box.select_and_activate (this);
            }
        }
        
        public override void show () {
            OrderBox box = this.get_box ();
            
            base.show ();
            
            if (box != null) {
                box.visibility_changed (this);
            }
        }
        
        public override void hide () {
            OrderBox box = this.get_box ();
            
            base.hide ();
            
            if (box != null) {
                box.visibility_changed (this);
            }
        }
        
        public override bool draw (Cairo.Context cr) {
            Gtk.Allocation allocation = Gtk.Allocation ();
            Gtk.StyleContext context = this.get_style_context ();
            Gtk.StateFlags state = this.get_state_flags ();
            Gtk.Border border;
            
            this.get_allocation (out allocation);
            
            context.render_background (
                cr, 0, 0,
                (double) allocation.width, (double) allocation.height
            );
            context.render_frame (
                cr, 0, 0, 
                (double) allocation.width, (double) allocation.height
            );
            
            if (this.has_visible_focus ()) {
                border = context.get_border (state);
                context.render_focus (
                    cr, border.left, border.top, 
                    allocation.width - border.left - border.right,
                    allocation.height - border.top - border.bottom
                );
            }
            
            base.draw (cr);
            
            return true;
        }
        
        private Gtk.Border get_full_border () {
            Gtk.StyleContext context = this.get_style_context ();
            Gtk.StateFlags state = context.get_state ();
            Gtk.Border padding, border, full_border;
            
            padding = context.get_padding (state);
            border = context.get_border (state);
            
            full_border = Gtk.Border ();
            full_border.left = padding.left + border.left;
            full_border.right = padding.right + border.right;
            full_border.top = padding.top + border.top;
            full_border.bottom = padding.bottom + border.bottom;
            return full_border;
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
         * get_preferred_* should not call get_preferred_*
         */
        private void preferred_height_for_width_internal (int width,
                                                          out int minimum_height,
                                                          out int natural_height)
        {
            Gtk.Widget child = this.get_child ();
            Gtk.Border full_border = get_full_border ();
            int child_min = 0, child_natural = 0;
            
            if (child != null && child.get_visible()) {
                int reservated = full_border.left + full_border.right;
                child.get_preferred_height_for_width (
                    width - reservated, out child_min, out child_natural
                );
            }
            
            minimum_height = full_border.top + child_min + full_border.bottom;
            natural_height = full_border.top + child_natural + full_border.bottom;
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
         * get_preferred_* should not call get_preferred_*
         */
        private void preferred_width_internal (out int minimum_width, 
                                               out int natural_width)
        {
            Gtk.Widget child = this.get_child ();
            int child_min = 0, child_natural = 0;
            Gtk.Border full_border = get_full_border ();
            
            if (child != null && child.get_visible()) {
                child.get_preferred_width (out child_min, out child_natural);
            }
            
            minimum_width = full_border.left + child_min + full_border.right;
            natural_width = full_border.left + child_natural + full_border.right;
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
            get_preferred_width (out minimum_width, out natural_width);
        }
        
        public override void size_allocate (Gtk.Allocation allocation) {
            Gtk.Widget child = this.get_child ();
            this.set_allocation (allocation);
            
            if (child != null && child.get_visible ()) {
                Gtk.Allocation child_allocation = Gtk.Allocation ();
                Gtk.Border border = get_full_border ();
                
                child_allocation.x = allocation.x + border.left;
                child_allocation.y = allocation.y + border.top;
                child_allocation.width = allocation.width - border.left - border.right;
                child_allocation.height = allocation.height - border.top - border.bottom;
                
                child.size_allocate (child_allocation);
            }
        }

        /**
         * Marks row as changed, causing any state that depends on this
         * to be updated.
         */
        public void changed () {
            OrderBox box;
            
            box = this.get_box ();
            if (box != null) {
                box.got_row_changed (this);
            }
        }
        
        /**
         * Gets the current index of this row in its OrderBox container.
         */
        public int get_index () {
            if (this.iter != null) {
                return iter.get_position ();
            }
            
            return -1;
        }
        
        /**
         * Returns whether this row is currently selected.
         */
        public bool is_selected () {
            return this.selected;
        }
        
        private OrderBox? get_box () {
            OrderBox parent;
            
            parent = this.get_parent () as OrderBox;
            return parent;
        }
        
        internal bool set_selected (bool selected) {
            if (!selectable) {
                return false;
            }
            
            if (this.selected != selected) {
                this.selected = selected;
                if (selected) {
                    set_state_flags (Gtk.StateFlags.SELECTED, false);
                } else {
                    unset_state_flags (Gtk.StateFlags.SELECTED);
                }
                
                this.queue_draw ();
                
                return true;
            }
            
            return false;
        }
    }
}
