namespace GDriveSync.AuthInfo {

    const string access_token_key = "access_token";
    const string refresh_token_key = "refresh_token";
    const string expires_in_key = "expires_in";
    const string issued_key = "issued";

    string access_token;
    string refresh_token;
    int64 expires_in;
    int64 issued;
    
    public bool hasValidAccessToken() {
        var now = new DateTime.now_local().to_unix();
        return access_token != null && now < (issued + expires_in);
    }

    void read() {
        LocalMeta localMeta = new LocalMeta();
        access_token = localMeta.get(access_token_key);
        refresh_token = localMeta.get(refresh_token_key);
        expires_in = int64.parse(localMeta.get(expires_in_key));
        issued = int64.parse(localMeta.get(issued_key));
    }

    void persist() {
        LocalMeta localMeta = new LocalMeta();
        localMeta.set(access_token_key, access_token);
        localMeta.set(refresh_token_key, refresh_token); 
        localMeta.set(expires_in_key, expires_in.to_string());
        localMeta.set(issued_key, issued.to_string());
    }

}