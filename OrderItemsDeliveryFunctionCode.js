/**
** This also required running `npm install @azure/cosmos` and `npm install uuidv4` inside the functions app
**/
const { CosmosClient } = require('@azure/cosmos');
const { v4: uuidv4 } = require('uuid');

const endpoint = process.env.COSMOS_DB_ENDPOINT;
const key = process.env.COSMOS_DB_KEY;
const databaseId = "OrdersToDeliver";
const containerId = "Items";

const client = new CosmosClient({ endpoint, key });
const database = client.database(databaseId);
const container = database.container(containerId);

module.exports = async function (context, req) {
    context.log('OrderItemsDelivery function is triggered via HTTP request.');

    if (req.body) {
        const item = req.body;

        // Generate a random orderID if not provided
        if (!item.orderId) {
            item.orderId = uuidv4();
            context.log(`Generated new orderId: ${item.orderId}`);
        }

        try {
            const { resource: createdItem } = await container.items.create(item);
            context.res = {
                status: 200,
                body: `Order for delivery created successfully: ${createdItem.id}`
            };
        } catch (err) {
            context.log(err);
            context.res = {
                status: 500,
                body: `Failed to create order: ${err.message}`
            };
        }
    }
}