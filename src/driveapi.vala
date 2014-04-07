using Json;
using Gee;

namespace GDriveSync {

    class Entry : GLib.Object {
        public string id;
        public string parentId;
        public string title;
        public bool isFolder;
        public bool isParentRoot;
        public string path;
    }

    class DriveAPI : GLib.Object {

        Soup.Session session = new Soup.Session();
        HashMap<string, Entry> map;

        public DriveAPI() {
            session = new Soup.Session();
            map = new HashMap<string, Entry>();
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
            parser.load_from_data (data, -1);
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

            stdout.printf("Map size: %d", map.size);
            
            // loop entries and recurse on parentId to calc path for all entires
            foreach (var entry in map.values) {
                if (entry.isParentRoot) {
                    entry.path = "/" + entry.title;
                }
            }

            do {
                                
            } while (parsePaths()>0);

            foreach (var entry in map.values) {
                if (entry.path != null) print(entry.path + "\n");
            }
            
            /*id
            mimeType == "application/vnd.google-apps.folder"
            title
            selfLink
            modifiedDate
            
            parents
              id
            */
        }
    }

}
