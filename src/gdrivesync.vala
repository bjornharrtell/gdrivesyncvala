using GDriveSync.AuthInfo;

namespace GDriveSync {

    class GDriveSync : GLib.Object {

        public static int main(string[] args) {

            Auth.authenticate();

            var api = new DriveAPI();
            
            api.getFiles();

            return 0;
        } 
    }

}