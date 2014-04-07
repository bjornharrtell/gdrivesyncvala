using GConf;
using GDriveSync.AuthInfo;

namespace GDriveSync.GConf  {

    const string access_token_key = "/apps/gdrivesync/auth/access_token";
    const string refresh_token_key = "/apps/gdrivesync/auth/refresh_token";
    const string expires_in_key = "/apps/gdrivesync/auth/expires_in";

    public void persist(string access_token, string refresh_token, int expires_in) {
        Client gc = Client.get_default();
        gc.set_string(refresh_token_key, refresh_token);
        gc.set_string(access_token_key, access_token);
        gc.set_int(expires_in_key, expires_in);
    }

    public void read() {
        Client gc = Client.get_default();
        refresh_token = gc.get_string(refresh_token_key);
        access_token = gc.get_string(access_token_key);
        expires_in = gc.get_int(expires_in_key);
    }
}
