package com.rasadeportes.rasaapp.repository;

import com.rasadeportes.rasaapp.model.Producto;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface ProductoRepository extends JpaRepository <Producto, Long> {
}
