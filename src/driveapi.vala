using Gee;

namespace GDriveSync {

    class Entry : GLib.Object {
        public string id;
        public string parentId;
        public string title;
        public bool isFolder;
        public bool isParentRoot;
        public string path;
        public Gee.List<Entry> children;
        public string selfLink;
        public string modifiedDate;
        public string downloadUrl;
    }

    class DriveAPI : GLib.Object {

        Soup.Session session = new Soup.Session();
        Map<string, Entry> map;
        Map<string, Entry> folders;

        public DriveAPI() {
            session = new Soup.Session();
            map = new HashMap<string, Entry>();
            folders = new HashMap<string, Entry>();
        }
        
        public void parseItems(string? nextLink = null) {
            var link = nextLink != null ? nextLink : @"https://www.googleapis.com/drive/v2/files?maxResults=1000";
            link += @"&access_token=$(AuthInfo.access_token)";

            print(link + "\n");

            var message = new Soup.Message("GET", link);
            session.send_message(message);
            var data = (string) message.response_body.flatten().data;

            debug("Got response from Google Drive API");
		    debug(data);
            
            var parser = new Json.Parser();

            try {
                parser.load_from_data (data, -1);
            } catch (Error e) {
                critical(e.message);
            }
            
            var root_object = parser.get_root().get_object();
            
            var items = root_object.get_array_member("items");
            
            // parse json to entries
            // ignore items with other than 1 parent
            foreach (var item in items.get_elements()) {
                var item2 = item.get_object();
                var entry = new Entry();
                entry.id = item2.get_string_member("id");
                var parents = item2.get_array_member("parents");
                if (parents.get_length() != 1) continue;
                var parent = parents.get_object_element(0);
                entry.parentId = parent.get_string_member("id");
                entry.isParentRoot = parent.get_boolean_member("isRoot");
                entry.title = item2.get_string_member("title");
                entry.selfLink = item2.get_string_member("selfLink");
                entry.downloadUrl = item2.has_member("downloadUrl") ? item2.get_string_member("downloadUrl") : null;
                entry.children = new ArrayList<Entry>();
                var mimeType = item2.get_string_member("mimeType");
                entry.isFolder = mimeType == "application/vnd.google-apps.folder";
                map.set(entry.id, entry);
            }
        
            var next = root_object.has_member("nextLink") && !root_object.get_null_member("nextLink") ? root_object.get_string_member("nextLink") : null;
            if (next != null) parseItems(next);
        }

        int parsePaths() {
            int count = 0;
            foreach (var entry in map.values) {
                if (!entry.isParentRoot && entry.path == null) {
                    if (!map.has_key(entry.parentId)) continue;
                    var parentPath = map.get(entry.parentId).path;
                    if (parentPath != null) {
                        count++;
                        entry.path = parentPath + "/" + entry.title;
                    }
                }
            }
            return count;
        }

        bool allPathsResolved() {
            foreach (var entry in map.values) {
                if (entry.path == null) return false;
            }
            return true;
        }
        
        public void getFiles() {

            parseItems();

            stdout.printf("Map size: %d\n", map.size);

            int count = 0;
            
            foreach (var entry in map.values) {
                if (entry.isFolder) {
                    folders.set(entry.id, entry);
                    count++;
                }
            }

            stdout.printf("Folders: %d\n", count);

            count = 0;
            foreach (var entry in map.values) {
                // TODO: find out why some parents does not exist in the main list
                if (!folders.has_key(entry.parentId)) continue;
                var parent = folders.get(entry.parentId);
                parent.children.add(entry);
                count++;
            }

            stdout.printf("Children processed: %d\n", count);

            foreach (var folder in folders.values) {
                if (folder.isParentRoot) {
                    processFolder(folder);
                }
            }
        }

        void processFolder(Entry folder, string root = "/") {
            print("Processing folder: " + folder.title + "\n");

            var newDir = File.new_for_path ("test" + root + folder.title);
            try { newDir.make_directory(); } catch (Error e) {};
            
            foreach (var child in folder.children) {
                var path = root + folder.title + "/";
                if (child.isFolder) {
                    processFolder(child, path);
                } else if (child.downloadUrl != null) {
                    download(child.downloadUrl, path + child.title);
                }
            }
        }

        void download(string url, string path) {
            var url_auth = url + @"&access_token=$(AuthInfo.access_token)";
            
            var message = new Soup.Message("GET", url_auth);
            session.send_message(message);
            var data = message.response_body.flatten().data;

            try {
                var newFile = File.new_for_path ("test" + path);
                var os = newFile.create(FileCreateFlags.PRIVATE);
                size_t bytes_written;
                os.write_all (data, out bytes_written);
                os.close();
            } catch (Error e) {
                critical(e.message);
            }
        }
    }

}
