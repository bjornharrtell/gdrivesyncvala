using Json;
using Gee;

namespace GDriveSync {

    class Entry : GLib.Object {
        public string id;
        public string title;
        public bool isFile;
        public string path;
    }

    class DriveAPI : GLib.Object {

        public static void getFiles() {
            var session = new Soup.Session();
            
            var message = new Soup.Message("GET", @"https://www.googleapis.com/drive/v2/files?access_token=$(AuthInfo.access_token)");
            
            session.send_message(message);
            
            var data = (string) message.response_body.flatten().data;

		    debug("Got response from Google Drive API");
		    debug(data);
		
            var parser = new Json.Parser();
            parser.load_from_data (data, -1);
            var root_object = parser.get_root().get_object();

            var map = new HashMap<string, Entry>();
            
            var items = root_object.get_array_member("items");
            
            //print(items.get_length ());
            //int64 total = response.get_int_member ("numFound");
            stdout.printf ("got %lld results:\n\n", items.get_length ());
            
            /*foreach (var item in items.get_elements()) {
                var item2 = item.get_object();
                var entry = new Entry();
                entry.id = item2.get_string_member("id");
                entry.title = item2.get_string_member("title");
                map.set(entry.id, entry);
                print(entry.id + " " + entry.title);
            }*/
            
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
