package handlers

import (
	"encoding/json"
	"net/http"
	"transaction-service/services"

	"github.com/graphql-go/graphql"
)

type GraphQLHandler struct {
	txService *services.TransactionService
	schema    graphql.Schema
}

func NewGraphQLHandler(svc *services.TransactionService) *GraphQLHandler {
	// Definimos un esquema básico
	queryType := graphql.NewObject(graphql.ObjectConfig{
		Name: "Query",
		Fields: graphql.Fields{
			"batchStatus": &graphql.Field{
				Type: graphql.String,
				Args: graphql.FieldConfigArgument{
					"batchId": &graphql.ArgumentConfig{Type: graphql.String},
				},
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					id := p.Args["batchId"].(string)
					return svc.GetStatus(id), nil
				},
			},
		},
	})

	schema, _ := graphql.NewSchema(graphql.SchemaConfig{
		Query: queryType,
	})

	return &GraphQLHandler{txService: svc, schema: schema}
}

func (h *GraphQLHandler) Handle(w http.ResponseWriter, r *http.Request) {
	result := graphql.Do(graphql.Params{
		Schema:        h.schema,
		RequestString: r.URL.Query().Get("query"),
	})
	json.NewEncoder(w).Encode(result)
}
