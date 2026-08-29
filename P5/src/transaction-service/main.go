package main

import (
	"fmt"
	"net/http"
	"transaction-service/handlers"
	"transaction-service/services"
)

// SOLID: Single Responsibility Principle (SRP)
// main.go solo se encarga de inyectar dependencias y levantar el servidor.

func main() {
	// SOLID: Dependency Inversion Principle (DIP)
	// Pasamos una implementación concreta (MockStorage) a la interfaz requerida por el servicio.
	storage := &services.MockStorage{}
	txService := services.NewTransactionService(storage)
	
	restHandler := handlers.NewRestHandler(txService)
	graphqlHandler := handlers.NewGraphQLHandler(txService)

	http.HandleFunc("/api/transactions/upload", restHandler.UploadCSV)
	http.HandleFunc("/graphql", graphqlHandler.Handle)

	fmt.Println("Transaction Service (Go) corriendo en puerto 4001")
	http.ListenAndServe(":4001", nil)
}
