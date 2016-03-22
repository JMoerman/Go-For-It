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

using GOFI;

namespace GOFI.Application {
    
    /**
     * The widget for selecting, displaying and controlling the active task.
     */
    public class TimerView : Gtk.Grid {
        /* Various Variables */
        private TaskTimer timer;

        /* GTK Widgets */
        private Gtk.ProgressBar progress;
        private Gtk.Label task_status_lbl;
        private Gtk.Label task_description_lbl;
        private Gtk.Grid timer_grid;
        private Gtk.SpinButton h_spin;
        private Gtk.SpinButton m_spin;
        private Gtk.SpinButton s_spin;
        private Gtk.Grid action_grid;
        private Gtk.Grid action_timer_grid;
        private Gtk.Grid action_task_grid;
        private Gtk.Button run_btn;
        private Gtk.Button skip_btn;
        public Gtk.Button done_btn;

        public TimerView (TaskTimer timer) {
            this.timer = timer;

            /* Settings of the widget itself */
            this.orientation = Gtk.Orientation.VERTICAL;
            this.expand = true;

            setup_task_widgets ();
            setup_timer_container ();
            setup_action_container ();
            setup_progress_bar ();

            set_running (timer.running);

            // Connect the timer's signals
            timer.timer_updated.connect (set_time);
            timer.timer_running_changed.connect (set_running);
            timer.active_task_changed.connect (timer_active_task_changed);
            timer.active_task_data_changed.connect (
                timer_active_task_data_changed
            );
            timer.timer_updated_relative.connect ((s, p) => {
                progress.set_fraction (p);
            });

            // Update timer, to refresh the view
            timer.update ();
        }
        
        private void timer_active_task_changed (TodoTask? task,
                                                bool break_active) {
            
            if (task == null) {
                reset ();
                return;
            }
            
            task_description_lbl.label = task.title;
            var style = task_description_lbl.get_style_context ();

            // Append correct class according to break status
            if (break_active) {
                task_status_lbl.label = _("Take a Break") + "!";
                style.remove_class ("task_active");
                style.add_class ("task_break");
            } else {
                task_status_lbl.label = _("Active Task") + ":";
                style.remove_class ("task_break");
                style.add_class ("task_active");
                done_btn.visible = true;
            }
        }
        
        private void timer_active_task_data_changed (TodoTask task) {
            task_description_lbl.label = task.title;
        }
        
        public void set_time (DateTime time) {
            h_spin.value = time.get_hour ();
            m_spin.value = time.get_minute ();
            s_spin.value = time.get_second ();
        }

        public void set_running (bool running) {
            done_btn.visible = !timer.break_active;

            if (running) {
                run_btn.label = _("Pau_se");
                run_btn.get_style_context ().remove_class ("suggested-action");
            } else {
                run_btn.label = _("_Start");
                run_btn.get_style_context ().add_class ("suggested-action");
            }
        }
        
        private void on_run_btn_clicked () {
            if (timer.running) {
                timer.stop ();
            }
            else {
                timer.start ();
            }
        }

        public DateTime get_timer_values ()  {
            var duration = new DateTime.from_unix_utc (0);
            duration = duration.add_hours ((int) h_spin.value);
            duration = duration.add_minutes ((int) m_spin.value);
            duration = duration.add_seconds (s_spin.value);
            return duration;
        }

        /**
         * Configures the widgets that indicate the active task and its progress
         */
        private void setup_task_widgets () {
            /* Instantiation */
            task_status_lbl = new Gtk.Label (_("Inactive"));
            task_description_lbl = new Gtk.Label (_("No task has been selected"));

            /* Configuration */
            task_status_lbl.margin_top = 30;
            task_status_lbl.get_style_context ().add_class ("task_status");
            task_description_lbl.margin = 20;
            task_description_lbl.margin_top = 30;
            task_description_lbl.lines = 3;
            task_description_lbl.wrap = true;
            task_description_lbl.wrap_mode = Pango.WrapMode.WORD_CHAR;
            task_description_lbl.width_request = 100;

            /* Add Widgets */
            this.add (task_status_lbl);
            this.add (task_description_lbl);
        }

        /**
         * Configures the container with the timer elements.
         */
        private void setup_timer_container () {
            /* Instantiation */
            timer_grid = new Gtk.Grid ();
            h_spin = new Gtk.SpinButton.with_range (0, 59, 1);
            m_spin = new Gtk.SpinButton.with_range (0, 59, 1);
            s_spin = new Gtk.SpinButton.with_range (0, 59, 1);

            /* Configuration */
            timer_grid.expand = true;
            timer_grid.orientation = Gtk.Orientation.HORIZONTAL;
            timer_grid.halign = Gtk.Align.CENTER;
            timer_grid.valign = Gtk.Align.CENTER;
            // Add CSS class
            timer_grid.get_style_context ().add_class ("timerview");
            h_spin.orientation = Gtk.Orientation.VERTICAL;
            m_spin.orientation = Gtk.Orientation.VERTICAL;
            s_spin.orientation = Gtk.Orientation.VERTICAL;

            use_leading_zeros (h_spin);
            use_leading_zeros (m_spin);
            use_leading_zeros (s_spin);

            /* Signal Handling */
            h_spin.value_changed.connect (() => {
                timer.remaining_duration = get_timer_values ();
            });
            m_spin.value_changed.connect (() => {
                timer.remaining_duration = get_timer_values ();
            });
            s_spin.value_changed.connect (() => {
                timer.remaining_duration = get_timer_values ();
            });

            /* Add Widgets */
            timer_grid.add (h_spin);
            timer_grid.add (new Gtk.Label (" : "));
            timer_grid.add (m_spin);
            timer_grid.add (new Gtk.Label (" : "));
            timer_grid.add (s_spin);
            this.add (timer_grid);
        }

        /**
         * Makes the passed Gtk.SpinButton fill the display with a leading zero.
         */
        private void use_leading_zeros (Gtk.SpinButton spin) {
            spin.output.connect ((s) => {
                var val = spin.get_value_as_int ();
                // If val <= 10, it's a single digit, so a leading zero is necessary
                if (val < 10) {
                    spin.text = "0" + val.to_string ();
                    return true;
                }
                return false;
            });
        }

        /**
         * Configures the container with the action buttons.
         */
        private void setup_action_container () {
            /* Instantiation */
            action_grid = new Gtk.Grid ();
            action_timer_grid = new Gtk.Grid ();
            action_task_grid = new Gtk.Grid ();
            run_btn = new Gtk.Button ();
            skip_btn = new Gtk.Button.with_label (_("S_kip"));
            done_btn = new Gtk.Button.with_label (_("_Done"));

            /* Configuration */
            action_grid.orientation = Gtk.Orientation.HORIZONTAL;
            action_grid.hexpand = true;
            action_timer_grid.hexpand = true;
            action_task_grid.hexpand = true;
            action_timer_grid.halign = Gtk.Align.END;
            action_task_grid.halign = Gtk.Align.START;
            done_btn.margin = 7;
            run_btn.margin = 7;
            skip_btn.margin = 7;
            // Use Mnemonics
            done_btn.use_underline = true;
            skip_btn.use_underline = true;
            run_btn.use_underline = true;

            /* Action Handling */
            skip_btn.clicked.connect ((e) => {
                timer.end_iteration ();
            });
            done_btn.clicked.connect ((e) => {
                timer.set_active_task_done();
            });
            run_btn.clicked.connect (on_run_btn_clicked);

            /* Add Widgets */
            action_timer_grid.add (skip_btn);
            action_timer_grid.add (run_btn);
            action_task_grid.add (done_btn);
            action_grid.add (action_task_grid);
            action_grid.add (action_timer_grid);
            this.add (action_grid);
        }

        private void setup_progress_bar () {
            progress = new Gtk.ProgressBar ();
            progress.hexpand = true;
            this.add (progress);
        }
        
        public override void show_all () {
            base.show_all ();
            done_btn.visible = (timer.active_task != null);
        }

        /**
         * This funciton is to be called, when the to-do list is empty
         */
        public void show_no_task () {
            task_status_lbl.label = _("Relax") + "." ;
            task_description_lbl.label = _("You have nothing to do.");
            done_btn.visible = false;
        }
        
        public void reset () {
            task_status_lbl.label = (_("Inactive"));
            task_description_lbl.label = (_("No task has been selected"));
            done_btn.visible = false;
        }
    }
}
