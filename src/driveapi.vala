using Gee;

namespace GDriveSync {

    

    class DriveAPI : GLib.Object {

        class Item : GLib.Object {
            public string id;
            public string parentId;
            public string title;
            public bool isFolder;
            public bool isParentRoot;
            public string path;
            public Gee.List<Item> children;
            public string downloadUrl;
            public string modifiedDate;
            public string fileSize;
            public Item local;

            public Item() {
                children = new ArrayList<Item>();
            }
        }
        
        Soup.Session session = new Soup.Session();
        Map<string, Item> items;
        Map<string, Item> folders;

        public DriveAPI() {
            session = new Soup.Session();
            items = new HashMap<string, Item>();
            folders = new HashMap<string, Item>();
        }
        
        public void parseItems(string? nextLink = null) {
            var link = nextLink != null ? nextLink : @"https://www.googleapis.com/drive/v2/files?maxResults=1000&q=trashed%3Dfalse";
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
            
            var json = parser.get_root().get_object();
            
            var itemsNode = json.get_array_member("items");
            
            // parse json to entries
            // ignore items with other than 1 parent
            foreach (var element in json.get_array_member("items").get_elements()) {
                var object = element.get_object();
                var item = new Item();
                item.id = object.get_string_member("id");
                var parents = object.get_array_member("parents");
                if (parents.get_length() != 1) continue;
                var parent = parents.get_object_element(0);
                item.parentId = parent.get_string_member("id");
                item.isParentRoot = parent.get_boolean_member("isRoot");
                item.title = object.get_string_member("title");
                item.downloadUrl = object.has_member("downloadUrl") ? object.get_string_member("downloadUrl") : null;
                var mimeType = object.get_string_member("mimeType");
                item.isFolder = mimeType == "application/vnd.google-apps.folder";
                items.set(item.id, item);
            }
        
            var next = json.has_member("nextLink") && !json.get_null_member("nextLink") ? json.get_string_member("nextLink") : null;
            if (next != null) parseItems(next);
        }
        
        public void getFiles() {

            parseItems();

            stdout.printf("Map size: %d\n", items.size);

            int count = 0;
            
            foreach (var item in items.values) {
                if (item.isFolder) {
                    folders.set(item.id, item);
                    count++;
                }
            }

            stdout.printf("Folders: %d\n", count);

            count = 0;

            var rootFolder = new Item();
            foreach (var item in items.values) {
                if (item.isParentRoot) {
                    if (!item.isFolder) rootFolder.children.add(item);
                } else {
                    // TODO: find out why some parents does not exist in the main list
                    if (!folders.has_key(item.parentId)) {
                        warning(item.title + " has no parent, skipping!");
                        continue;
                    }
                    var parent = folders.get(item.parentId);
                    parent.children.add(item);
                }
                
                count++;
            }

            stdout.printf("Items processed: %d\n", count);

            processFolder(rootFolder);
            /*foreach (var folder in folders.values) {
                if (folder.isParentRoot) {
                    processFolder(folder);
                }
            }*/
        }

        void processFolder(Item folder, string root = "/") {
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
