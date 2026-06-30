package com.rasadeportes.rasaapp.repository;

import com.rasadeportes.rasaapp.model.Imagen;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ImagenRepository extends JpaRepository <Imagen, Long> {

    List<Imagen> findByProductoId(Long productoId);

    Imagen findByProductoIdAndEsPrincipalTrue(Long productoId);

}
