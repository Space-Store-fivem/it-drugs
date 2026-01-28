CREATE TABLE IF NOT EXISTS `it_war_requests` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `zone_id` VARCHAR(50) NOT NULL,
    `attacker_gang` VARCHAR(50) NOT NULL,
    `defender_gang` VARCHAR(50) NOT NULL,
    `requested_by` INT(11) DEFAULT NULL,
    `status` ENUM('requested', 'approved', 'rejected', 'cancelled', 'completed') DEFAULT 'requested',
    `reason` TEXT DEFAULT NULL,
    `rejection_reason` TEXT DEFAULT NULL,
    `requested_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `scheduled_time` DATETIME DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
