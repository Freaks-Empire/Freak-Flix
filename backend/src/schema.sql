DROP TABLE IF EXISTS media_items;
DROP TABLE IF EXISTS library_folders;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
  id TEXT PRIMARY KEY, -- UUID
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at INTEGER DEFAULT (unixepoch())
);

CREATE TABLE library_folders (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  path TEXT NOT NULL,
  provider TEXT NOT NULL, -- 'onedrive'
  provider_id TEXT NOT NULL, -- folder_id on onedrive
  last_scanned_at INTEGER,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE media_items (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  folder_id TEXT NOT NULL, -- references library_folders(id)
  title TEXT,
  filename TEXT NOT NULL,
  size_bytes INTEGER,
  mime_type TEXT,
  provider_item_id TEXT NOT NULL, -- item id on onedrive
  download_url TEXT, -- Might expire, but good to cache if long lived? No, graph urls expire.
  metadata JSON, -- All other metadata
  created_at INTEGER DEFAULT (unixepoch()),
  updated_at INTEGER DEFAULT (unixepoch()),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (folder_id) REFERENCES library_folders(id)
);

CREATE INDEX idx_media_user ON media_items(user_id);
CREATE INDEX idx_media_folder ON media_items(folder_id);
