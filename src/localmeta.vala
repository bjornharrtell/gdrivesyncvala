using Gee;

namespace GDriveSync {

    class FileMeta : GLib.Object {
        public string path { get; set; }
        public bool isFolder { get; set; }
        public bool isDeleted { get; set; }
        public string id { get; set; }
    }

    class LocalMeta {
        static string path = Path.build_filename(Environment.get_home_dir(), CONFIGFOLDER, LOCALMETAFILE);
        
        Gee.List<FileMeta> _files = new ArrayList<FileMeta>();

        public Gee.List<FileMeta> files { get { return _files; } }

        public void readFromPath(owned string? path = null) {
            if (path == null) {
                path = Path.build_filename(output, ROOTFOLDER);
            }

            var dir = Dir.open(path);
            string? name = null;
            while ((name = dir.read_name ()) != null) {
                var filePath = Path.build_filename(path, name);
                var file = File.new_for_path(filePath);
                var fileMeta = new FileMeta();
                try {
                    FileInfo info = file.query_info ("standard::*,time::*", FileQueryInfoFlags.NONE);
                    var type = info.get_file_type();
                    var size = info.get_size();
                    var modifiedDate = info.get_modification_time().tv_sec;
                    if (type == FileType.DIRECTORY) {
                        fileMeta.path = filePath;
                        fileMeta.isFolder = true;
                        fileMeta.isDeleted = false;
                        readFromPath(filePath);
                    } else if (type == FileType.REGULAR) {
                        fileMeta.path = filePath;
                        fileMeta.isFolder = false;
                        fileMeta.isDeleted = false;
                    }
                    files.add(fileMeta);
                } catch (Error e) {
                    // Failed to get local info, ignore and move on...
                }
            }
        }

        public void load() {
            Json.Parser parser = new Json.Parser ();
	        try {
		        parser.load_from_file(path);
                
		        Json.Node node = parser.get_root ();

                var object = node.get_object();
                var array = object.get_array_member("files");
                foreach (var element in array.get_elements()) {
                    FileMeta fileMeta = Json.gobject_deserialize (typeof (FileMeta), element) as FileMeta;
                    files.add(fileMeta);
                }
	        } catch (Error e) {
		        
	        }
        }

        public void save() {
            size_t length;

            var generator = new Json.Generator();
            var root = new Json.Node(Json.NodeType.OBJECT);
            var object = new Json.Object();
            root.set_object(object);
            generator.set_root(root);

            var array = new Json.Array();

            foreach (var file in files) {
                Json.Node node = Json.gobject_serialize (file);
                array.add_element(node);
            };

            object.set_string_member("version", VERSION);
            object.set_int_member("timestamp", new DateTime.now_utc().to_unix());
            object.set_array_member("files", array);
            
            var dir = Path.get_dirname(path);
            File file = File.new_for_path(dir);
            file.make_directory_with_parents();
            
            generator.to_file(path);
        }
    }

}

    