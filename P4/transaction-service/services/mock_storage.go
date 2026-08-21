package services

import "fmt"

// Implementación concreta para desarrollo
type MockStorage struct{}

func (m *MockStorage) SaveBatch(batchID string, data string) error {
	fmt.Printf("[MockStorage] Lote %s guardado exitosamente.\n", batchID)
	return nil
}

func (m *MockStorage) GetBatchStatus(batchID string) string {
	return "PENDING_CHECKER"
}
