CREATE DATABASE IF NOT EXISTS `valerian`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE `valerian`;

CREATE TABLE IF NOT EXISTS `vn_hud_needs` (
    `identifier` VARCHAR(80)  NOT NULL,
    `hunger`     DOUBLE       NOT NULL DEFAULT 100,
    `thirst`     DOUBLE       NOT NULL DEFAULT 100,
    `updated_at` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
