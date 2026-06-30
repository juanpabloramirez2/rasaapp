-- V1 - Schema inicial Rasa Deportes

CREATE TABLE IF NOT EXISTS categorias (
    id     BIGINT       NOT NULL AUTO_INCREMENT,
    nombre VARCHAR(255) NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS productos (
    id           BIGINT         NOT NULL AUTO_INCREMENT,
    nombre       VARCHAR(255)   NOT NULL,
    descripcion  TEXT,
    precio       DOUBLE         NOT NULL,
    categoria_id BIGINT         NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_producto_categoria (categoria_id),
    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (categoria_id) REFERENCES categorias (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS imagenes (
    id           BIGINT       NOT NULL AUTO_INCREMENT,
    url          VARCHAR(255) NOT NULL,
    es_principal TINYINT(1)   NOT NULL DEFAULT 0,
    producto_id  BIGINT       NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_imagen_producto (producto_id),
    CONSTRAINT fk_imagen_producto
        FOREIGN KEY (producto_id) REFERENCES productos (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS variantes (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    talla       VARCHAR(255),
    color       VARCHAR(255),
    cantidad    INT          NOT NULL DEFAULT 0,
    producto_id BIGINT       NOT NULL,
    PRIMARY KEY (id),
    INDEX idx_variante_producto (producto_id),
    CONSTRAINT fk_variante_producto
        FOREIGN KEY (producto_id) REFERENCES productos (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS usuarios (
    id       BIGINT       NOT NULL AUTO_INCREMENT,
    username VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL,
    rol      VARCHAR(255),
    enabled  TINYINT(1)   DEFAULT 1,
    PRIMARY KEY (id),
    UNIQUE KEY uq_usuario_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
