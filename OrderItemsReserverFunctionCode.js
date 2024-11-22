###
# This also required running `npm install @azure/storage-blob` inside the functions app after creating package.json file
###
const { BlobServiceClient } = require('@azure/storage-blob');

const AZURE_STORAGE_CONNECTION_STRING = process.env["AzureWebJobsStorage"];
const STORAGE_CONTAINER_NAME = 'eshop-orders';

module.exports = async function (context, req) {
    context.log('OrderItemsReserver function is triggered via HTTP request.');

    if (req.body) {
        try {
            const blobServiceClient = BlobServiceClient.fromConnectionString(AZURE_STORAGE_CONNECTION_STRING);
            const containerClient = blobServiceClient.getContainerClient(STORAGE_CONTAINER_NAME);

            // Create the container if it does not exist
            await containerClient.createIfNotExists({
                access: 'container'
            });

            // Get the current time to create a unique blob name
            const timestamp = new Date().toISOString();
            const blobName = `eshop-order-${timestamp}.json`;
            const blockBlobClient = containerClient.getBlockBlobClient(blobName);

            const jsonContent = JSON.stringify(req.body);
            await blockBlobClient.upload(jsonContent, Buffer.byteLength(jsonContent));

            context.res = {
                status: 200,
                body: "Successfully created and uploaded order with name: " + blobName
            };
        } catch (err) {
            context.log(err);
            context.res = {
                status: 500,
                body: `Failed to upload order: ${err.message}`
            };
        }
    } else {
        context.res = {
            status: 400,
            body: "Please pass a valid JSON in the request body."
        };
    }
}