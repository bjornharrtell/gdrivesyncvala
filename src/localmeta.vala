using Gee;

using Sqlite;

namespace GDriveSync {

    class LocalMeta {
        string path = Path.build_filename(Environment.get_home_dir(), CONFIGFOLDER, LOCALMETADB);
        
        Database db;
        string errmsg;

        public LocalMeta() {
            var rc = Database.open(path, out db);

            if (rc != Sqlite.OK) {
                critical("Can't open database. Error: %s",db.errmsg ());
            }

            createschema();
        }

        void check(int err) {
            if (err!= Sqlite.OK) {
                critical("Sqlite error: %s", db.errmsg());
            }
        }

        void createschema() {
            string query = """
		        CREATE TABLE localmeta (
			        path    TEXT	PRIMARY KEY		NOT NULL
		        );

		        INSERT INTO User (id, name) VALUES (1, 'Hesse');
		        INSERT INTO User (id, name) VALUES (2, 'Frisch');
		    """;
	        db.exec(query, null, out errmsg);
        }

        public void insert(string path) {
            message("Insert: " + path);
            string query = @"INSERT INTO localmeta (path) VALUES ('$(path)')";
	        check(db.exec(query, null, out errmsg));
        }

        public void remove(string path) {
            message("Remove: " + path);
            string query = @"DELETE FROM localmeta WHERE path = '$(path)'";
	        check(db.exec(query, null, out errmsg));
        }

        public bool exists(string path) {
            string query = @"SELECT path FROM localmeta WHERE path = '$(path)'";
            Sqlite.Statement stmt;
	        check(db.prepare_v2 (query, query.length, out stmt));
            var exists = stmt.step() == Sqlite.ROW;
            return exists;
        }
    }

}

    