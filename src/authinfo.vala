namespace GDriveSync.AuthInfo {
    public string access_token;
    public string refresh_token;
    public int64 expires_in;
    public int64 issued;

    bool hasValidAccessToken() {
        var now = new DateTime.now_local().to_unix();
        return access_token != null && now < (issued + expires_in);
    }
}