package com.rasadeportes.rasaapp.repository;

import com.rasadeportes.rasaapp.model.Variante;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;

public interface VarianteRepository extends JpaRepository <Variante, Long> {

    // COALESCE -> Si la suma es null, salta al valor siguiente = 0
    @Query("""
    SELECT COALESCE(SUM(v.cantidad), 0)
    FROM Variante v
    WHERE v.producto.id = :productoId
    """)
    Integer obtenerStockTotalPorProducto(Long productoId);

    List<Variante> findByProductoId(Long productoId);
}
