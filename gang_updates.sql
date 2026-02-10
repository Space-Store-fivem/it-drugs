CREATE TABLE IF NOT EXISTS `it_gang_metadata` (
  `gang_id` varchar(50) NOT NULL,
  `logo_url` text DEFAULT NULL,
  `updated_at` timestamp DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`gang_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `it_gang_sprays` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gang_id` varchar(50) NOT NULL,
  `x` float NOT NULL,
  `y` float NOT NULL,
  `z` float NOT NULL,
  `nx` float DEFAULT 0,
  `ny` float DEFAULT 0,
  `nz` float DEFAULT 0,
  `scale` float DEFAULT 1.0,
  `created_at` timestamp DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
