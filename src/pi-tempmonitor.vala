/*
 *  Pi Temperature Monitor Plugin
 *  Show the Current CPU Temp on Raspberry Pi Running Ubuntu Budgie
 *
 *  Copyright (C) 2020  Samuel Lane
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *  Icons made by Freepik from http://www.freepik.com
 *  https://www.flaticon.com
 */

using Gtk;

namespace PiTempMonitor {

    public class PiTempMonitorSettings : Gtk.Grid {

        private GLib.Settings app_settings;
        private Gtk.Switch switch_degree;
        private Gtk.SpinButton spinbutton_temp;

        public PiTempMonitorSettings(GLib.Settings? settings) {
        
            app_settings = new GLib.Settings ("com.github.samlane-ma.pi-temp-monitor");
            Gtk.Label label_temp = new Gtk.Label("\nOverheat temp: (in Celcius)");
            label_temp.set_halign(Gtk.Align.START);
            Gtk.Label spacer = new Gtk.Label("\n");
            Gtk.Label label_degree = new Gtk.Label("Display in Celcius:");
            label_degree.set_halign(Gtk.Align.START);
            switch_degree = new Gtk.Switch();
            switch_degree.set_halign(Gtk.Align.START);
            Gtk.Adjustment temp_adj = new Gtk.Adjustment(75,55,85,1,5,0);
            spinbutton_temp = new Gtk.SpinButton(temp_adj,1.0,0);
            this.attach(label_temp, 0, 0, 2, 1);
            this.attach(spinbutton_temp, 0, 1, 2, 1);
            this.attach(spacer,0, 2, 1, 1);
            this.attach(label_degree, 0, 3, 1, 1);
            this.attach(switch_degree, 1, 3, 1, 1);
            
            app_settings.bind("celcius",switch_degree,"active",SettingsBindFlags.DEFAULT);
            app_settings.bind("overheat",spinbutton_temp,"value",SettingsBindFlags.DEFAULT);
            this.show_all();
        }
    }


    public class Plugin : Budgie.Plugin, Peas.ExtensionBase {
        public Budgie.Applet get_panel_widget(string uuid) {
            return new PiTempMonitorApplet(uuid);
        }
    }

    public class PiTempMonitorPopover : Budgie.Popover {
        private Grid maingrid;
        private Gtk.Label min_temp;
        private Gtk.Label min_time;
        private Gtk.Label max_temp;
        private Gtk.Label max_time;

        public PiTempMonitorPopover(Gtk.EventBox indicatorBox) {
            GLib.Object(relative_to: indicatorBox);

            maingrid = new Gtk.Grid();
            min_temp = new Gtk.Label("");
            min_time = new Gtk.Label("");
            max_temp = new Gtk.Label("");
            max_time = new Gtk.Label("");
            Gtk.Label spacer = new Gtk.Label("");
            Gtk.Label lowtemp = new Gtk.Label("Lowest Temperature");
            Gtk.Label hitemp = new Gtk.Label("Highest Temperature");
            maingrid.attach(lowtemp, 0, 0, 1, 1);
            maingrid.attach(min_temp, 0, 1, 1, 1);
            maingrid.attach(min_time, 0, 2, 1, 1);
            maingrid.attach(spacer, 0, 3, 1, 1);
            maingrid.attach(hitemp, 0, 4, 1, 1);
            maingrid.attach(max_temp, 0, 5, 1, 1);
            maingrid.attach(max_time, 0, 6, 1, 1);

            this.add(this.maingrid);
            maingrid.show_all();
        }
        
        public void set_lowest_temp(string temp) {
            min_temp.set_text(temp);
        }

        public void set_lowest_time(string time) {
            min_time.set_text(time);
        }

        public void set_highest_temp(string temp) {
            max_temp.set_text(temp);
        }

        public void set_highest_time(string time) {
            max_time.set_text(time);
        }
    }

    public class PiTempMonitorApplet : Budgie.Applet {

        private GLib.Settings app_settings;
        private GLib.Settings? panel_settings;
        private GLib.Settings? currpanelsubject_settings;
        private string soluspath;
        private ulong panel_signal;
        private ulong? settings_signal;

        private Gtk.EventBox indicatorBox;
        private Gtk.Box panel_box;
        private Gtk.Image panel_icon;
        private Gtk.Label panel_temp;
        private PiTempMonitorPopover popover = null;
        private unowned Budgie.PopoverManager? manager = null;

        private int? max_temp;
        private int? min_temp;
        private int overheat_temp;
        private bool use_celcius;
        private bool overheating;
        private bool keep_running;
        public string uuid { public set; public get; }

        public PiTempMonitorApplet(string uuid) {
            /* box */
            this.uuid = uuid;

            app_settings = new GLib.Settings ("com.github.samlane-ma.pi-temp-monitor");
            soluspath = "com.solus-project.budgie-panel";
            use_celcius = app_settings.get_boolean("celcius");
            overheat_temp = app_settings.get_int("overheat");

            indicatorBox = new Gtk.EventBox();
            panel_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL,0);
            indicatorBox.add(panel_box);
            add(indicatorBox);
            panel_icon = new Gtk.Image.from_icon_name("sensors-temperature-symbolic", Gtk.IconSize.MENU);
            panel_temp = new Gtk.Label("°C");
            panel_box.pack_start(panel_temp);
            panel_box.pack_end(panel_icon);
            panel_icon.get_style_context().add_class("dim-label");
            
            overheating = false;
            keep_running = true;

            popover = new PiTempMonitorPopover(indicatorBox);
            set_minmax_temps(get_cpu_temp());
            update_panel(get_cpu_temp());

            indicatorBox.button_press_event.connect((e)=> {
                if (e.button != 1) {
                    return Gdk.EVENT_PROPAGATE;
                } 
                if (popover.get_visible()) {
                    popover.hide();
                } else {
                    this.manager.show_popover(indicatorBox);
                }
                return Gdk.EVENT_STOP;
            });
            show_all();

            settings_signal = app_settings.changed.connect(on_settings_change);
            Idle.add(() => { watch_applet(uuid); 
                             return false;});
            GLib.Timeout.add_seconds(5, check_temperature);
        }

        private void on_settings_change(string key){
            switch (key){
                case "overheat":
                    overheat_temp = app_settings.get_int("overheat");
                    break;
                case "celcius":
                    use_celcius = app_settings.get_boolean("celcius");
                    popover.set_lowest_temp(format_temp(min_temp, true));
                    popover.set_highest_temp(format_temp(max_temp, true));
                    break;
            }
            check_temperature();
        }

        private bool check_temperature() {
            // Get and display the cpu temp - also called when settings change
            int temp = get_cpu_temp();
            set_minmax_temps(temp);
            Idle.add(() => update_panel(temp));
            return keep_running;
        }

        private int get_cpu_temp() {
            // Read the CPU temp from "file" as string - return it as an int)
            try {
                var cputempfile = File.new_for_path("/sys/class/thermal/thermal_zone0/temp");
                var dis = new DataInputStream(cputempfile.read());
                string line = dis.read_line();
                return int.parse(line);
            }
            catch (Error e) {
                stdout.printf("Error: %s\n",e.message);
                return int.parse("0");
            }
        }

        private bool update_panel (int temp){
            // Update the panel temp and dim / brighten icon if needed
            panel_temp.set_text(format_temp(temp,false));
            if (!overheating && temp >= overheat_temp * 1000) {
                overheating = true;
                panel_icon.get_style_context().remove_class("dim-label");
            }
            else if (overheating && temp < overheat_temp * 1000) {
                overheating = false;
                panel_icon.get_style_context().add_class("dim-label");
            }
            return false;
        }

        private void set_minmax_temps (int temp) {
            // Set the popover min / max temperatures if needed
            if (max_temp == null || max_temp < temp) {
                var current_time = new DateTime.now_local();
                popover.set_highest_temp(format_temp(temp, true));
                popover.set_highest_time(current_time.format("%X %x"));
                max_temp = temp;
            }
            if (min_temp == null || min_temp > temp) {
                var current_time = new DateTime.now_local();
                popover.set_lowest_temp(format_temp(temp, true));
                popover.set_lowest_time(current_time.format("%X %x"));
                min_temp = temp;
            }
        }

        private string format_temp(int temp, bool use_full) {
            // True returns temp formatted to 3 decimal places for popover
            // False rounds temp, used for Budgie panel display
            string degree = (use_celcius ? "°C" : "°F");
            float fulltemp = (float)temp / 1000;
            fulltemp = (use_celcius ? fulltemp : (fulltemp * 9 / 5 + 32));
            if (use_full) {
                return fulltemp.to_string("%.3f") + degree;
            }
            else {
                return fulltemp.to_string("%.0f") + degree;
            }
        }
        
        private bool find_applet(string find_uuid, string[] applet_list) {
            // Search panel applets for the given uuid
            for (int i = 0; i < applet_list.length; i++) {
                if (applet_list[i] == find_uuid) {
                    return true;
                }
            }
            return false;
        }

        private void watch_applet(string find_uuid) {
            // Check if the applet is still on the panel and end cleanly if not
            string[] applets;
            panel_settings = new GLib.Settings(soluspath);
            string[] allpanels_list = panel_settings.get_strv("panels");
            foreach (string p in allpanels_list) {
                string panelpath = "/com/solus-project/budgie-panel/panels/".concat("{", p, "}/");
                currpanelsubject_settings = new GLib.Settings.with_path(
                    soluspath + ".panel", panelpath
                );
                applets = currpanelsubject_settings.get_strv("applets");
                if (find_applet(find_uuid, applets)) {
                     panel_signal = currpanelsubject_settings.changed["applets"].connect(() => {
                        applets = currpanelsubject_settings.get_strv("applets");
                        if (!find_applet(find_uuid, applets)) {
                            currpanelsubject_settings.disconnect(panel_signal);
                            app_settings.disconnect(settings_signal);
                            keep_running = false;
                        }
                    });
                }
            }
        }

        public override void update_popovers(Budgie.PopoverManager? manager)
        {
            this.manager = manager;
            manager.register_popover(indicatorBox, popover);
        }
        
        public override bool supports_settings()
        {
            return true;

        }
        public override Gtk.Widget? get_settings_ui()
        {
            return new PiTempMonitorSettings(this.get_applet_settings(uuid));
        }
    }
}

[ModuleInit]
public void peas_register_types(TypeModule module){
    /* boilerplate - all modules need this */
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type(typeof(
        Budgie.Plugin), typeof(PiTempMonitor.Plugin)
    );
}
