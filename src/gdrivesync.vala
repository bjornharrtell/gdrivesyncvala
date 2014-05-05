using GDriveSync.AuthInfo;

namespace GDriveSync {

    const string VERSION = "0.1.0";
    const string ROOTFOLDER = "Google Drive";
    const string CONFIGFOLDER = ".gdrivesync";
    const string LOCALMETAFILE = "localmeta.json";
    const string LOCALMETADB = "localmeta.db";
    
    bool version = false;
    string? output = null;
    bool notowned = false;
    bool exportdocs = false;
    
    class GDriveSync : GLib.Object {

        const OptionEntry[] options = {
		    { "version", 0, 0, OptionArg.NONE, ref version, "Display version number", null },
		    { "output", 'o', 0, OptionArg.FILENAME, ref output, "Output path", "DIRECTORY" },
            { "notowned", 0, 0, OptionArg.NONE, ref exportdocs, "Include files you do not own", null },
		    //{ "exportdocs", 0, 0, OptionArg.NONE, ref exportdocs, "Export Google Documents as PDF", null },
		    { null }
	    };

        public static int main(string[] args) {

            try {
			    var opt_context = new OptionContext();
			    opt_context.set_help_enabled (true);
			    opt_context.add_main_entries (options, null);
			    opt_context.parse (ref args);
		    } catch (OptionError e) {
			    stdout.printf ("error: %s\n", e.message);
			    stdout.printf ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
			    return 0;
		    }

            if (version) {
                stdout.printf ("GDriveSync %s\n", VERSION);
                return 0;
            }

            if (output == null) {
                output = "./gdrive";
            }
            
            Auth.authenticate();

            var root = new DriveFile.as_root();
            DriveFile.sync(root);

            return 0;
        } 
    }

}