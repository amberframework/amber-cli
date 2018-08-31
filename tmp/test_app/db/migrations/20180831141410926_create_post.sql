-- +micrate Up
CREATE TABLE posts (
  id INTEGER NOT NULL PRIMARY KEY,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);


-- +micrate Down
DROP TABLE IF EXISTS posts;
