-- Tabela para zonas de venda de drogas
CREATE TABLE IF NOT EXISTS `it_drug_zones` (
  `zone_id` VARCHAR(64) PRIMARY KEY,
  `label` VARCHAR(120) NOT NULL,
  `gang_name` VARCHAR(64) DEFAULT NULL,
  `color` VARCHAR(20) DEFAULT NULL COMMENT 'Hex Color #RRGGBB',
  `owner_cid` VARCHAR(64) NOT NULL,
  `polygon_points` TEXT DEFAULT NULL COMMENT 'JSON array de pontos do polígono [{x,y,z}, ...]',
  `thickness` DOUBLE NOT NULL DEFAULT 10.0,
  `drugs` TEXT DEFAULT NULL COMMENT 'JSON array de drogas [{item, price}, ...]',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Tabela para mesas de drogas dentro das zonas
CREATE TABLE IF NOT EXISTS `it_drug_tables` (
  `table_id` INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `zone_id` VARCHAR(64) NOT NULL,
  `coords` TEXT NOT NULL COMMENT 'JSON {x, y, z, heading}',
  `model` VARCHAR(64) DEFAULT 'bkr_prop_weed_table_01a',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`zone_id`) REFERENCES `it_drug_zones`(`zone_id`) ON DELETE CASCADE
);

