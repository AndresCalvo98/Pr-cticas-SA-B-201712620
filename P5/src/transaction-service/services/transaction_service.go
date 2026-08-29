package services

import "fmt"

// SOLID: Interface Segregation Principle (ISP)
// Creamos una interfaz pequeña y específica en lugar de una interfaz gigante.
type TransactionSaver interface {
	SaveBatch(batchID string, data string) error
}

type TransactionReader interface {
	GetBatchStatus(batchID string) string
}

// TransactionService depende de abstracciones, no implementaciones (DIP)
type TransactionService struct {
	saver  TransactionSaver
	reader TransactionReader
}

func NewTransactionService(storage interface {
	TransactionSaver
	TransactionReader
}) *TransactionService {
	return &TransactionService{
		saver:  storage,
		reader: storage,
	}
}

func (s *TransactionService) ProcessCSV(batchID, data string) error {
	fmt.Println("[TransactionService] Procesando CSV...")
	return s.saver.SaveBatch(batchID, data)
}

func (s *TransactionService) GetStatus(batchID string) string {
	return s.reader.GetBatchStatus(batchID)
}
