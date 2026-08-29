package handlers

import (
	"encoding/json"
	"net/http"
	"transaction-service/services"
)

type RestHandler struct {
	txService *services.TransactionService
}

func NewRestHandler(svc *services.TransactionService) *RestHandler {
	return &RestHandler{txService: svc}
}

func (h *RestHandler) UploadCSV(w http.ResponseWriter, r *http.Request) {
	// Simula recibir un CSV
	err := h.txService.ProcessCSV("batch-123", "csv_data")
	if err != nil {
		http.Error(w, "Error procesando", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"message": "Lote cargado", "batchId": "batch-123"})
}
