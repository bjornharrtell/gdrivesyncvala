using GDriveSync.AuthInfo;

namespace GDriveSync {

    class GDriveSync : GLib.Object {

        public static int main(string[] args) {

            Auth.authenticate();
            
            DriveAPI.getFiles();

            return 0;
        } 
    }

}