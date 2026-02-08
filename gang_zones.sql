CREATE TABLE IF NOT EXISTS `it_gang_zones` (
  `zone_id` varchar(50) NOT NULL,
  `label` varchar(50) DEFAULT 'Gang Zone',
  `owner_gang` varchar(50) DEFAULT NULL,
  `polygon_points` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`polygon_points`)),
  `color` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`color`)),
  `flag_point` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`flag_point`)),
  `visual_zone` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`visual_zone`)),
  `upgrades` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`upgrades`)),
  `current_status` varchar(20) DEFAULT 'peace',
  PRIMARY KEY (`zone_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

