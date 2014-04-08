using Gee;

namespace GDriveSync {

    class DriveAPI : GLib.Object {     
        
        class Item : GLib.Object {
            public string id;
            public string title;
            public bool isFolder;
            public string path;
            public string downloadUrl;
            //public string modifiedDate;
            //public string fileSize;

            //public string localModifiedDate;
            //public string localFileSize;

            public Gee.List<Item> children;

            public Item() {
                children = new ArrayList<Item>();
            }
        }
        
        Soup.Session session = new Soup.Session();
        Json.Parser parser = new Json.Parser();

        Json.Object requestJson(string url) {
            var message = new Soup.Message("GET", url);
            session.send_message(message);
            var data = (string) message.response_body.flatten().data;
            debug("Got response from Google Drive API");
		    //debug(data + "\n");
            try {
                parser.load_from_data (data, -1);
            } catch (Error e) {
                critical(e.message);
            }
            return parser.get_root().get_object();
        }

        void getItems(Item folder, string? nextLink = null) {
            debug("Processing folder: " + folder.title);

            var url = nextLink != null ? nextLink : @"https://www.googleapis.com/drive/v2/files?q=trashed+%3D+false+and+'$(folder.id)'+in+parents";
            url += @"&access_token=$(AuthInfo.access_token)";
            var json = requestJson(url);
            var items = json.get_array_member("items");
            
            foreach (var node in items.get_elements()) {
                var object = node.get_object();
                var item = new Item();
                item.id = object.get_string_member("id");
                var parents = object.get_array_member("parents");
                // NOTE: ignore items with other than 1 parent
                if (parents.get_length() != 1) continue;
                item.title = object.get_string_member("title");
                item.downloadUrl = object.has_member("downloadUrl") ? object.get_string_member("downloadUrl") : null;
                var mimeType = object.get_string_member("mimeType");
                item.isFolder = mimeType == "application/vnd.google-apps.folder";
                folder.children.add(item);
                if (item.isFolder) getItems(item);
            }
        
            var next = json.has_member("nextLink") && !json.get_null_member("nextLink") ? json.get_string_member("nextLink") : null;
            if (next != null) getItems(folder, next);
        }

        Item getRootFolder() {
            var url = "https://www.googleapis.com/drive/v2/about?";
            url += @"access_token=$(AuthInfo.access_token)";
            var json = requestJson(url);
            var rootFolderId = json.get_string_member("rootFolderId");
            var rootFolder = new Item();
            rootFolder.id = rootFolderId;
            rootFolder.title = "Google Drive";
            rootFolder.isFolder = true;

            debug("Root folder ID: " + rootFolderId);
            
            return rootFolder;
        }

        void processFiles(Item folder, string path = "") {
            folder.path = path + folder.title + "/";

            debug("Create directory at: " + folder.path);

            try { File.new_for_path(folder.path).make_directory(); } catch (Error e) {};
                        
            foreach (var child in folder.children) {
                if (child.isFolder) {
                    processFiles(child, folder.path);
                } else if (child.downloadUrl != null) {
                    child.path = folder.path + child.title;
                    download(child.downloadUrl, child.path);
                }
            }
        }
        
        public void getFiles() {
            // Future stuff: 
            // * populate tree structure with local information
            // * use local information to decide if download is needed
            // * use set diff on paths to find files not in Google Drive to be uploaded

            var rootFolder = getRootFolder();
            getItems(rootFolder);
            processFiles(rootFolder);
        }

        void download(string url, string path) {
            debug("Download file to: " + path);

            var url_auth = url + @"&access_token=$(AuthInfo.access_token)";
            
            var message = new Soup.Message("GET", url_auth);
            session.send_message(message);
            var data = message.response_body.flatten().data;

            try {
                var newFile = File.new_for_path (path);
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
