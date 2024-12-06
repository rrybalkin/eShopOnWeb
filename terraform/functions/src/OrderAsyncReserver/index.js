/**
 ** This also required running `npm install @azure/storage-blob` and `npm install axios` inside the functions app
 **/

const { BlobServiceClient } = require('@azure/storage-blob');
const axios = require('axios');

const connectionString = process.env["AzureWebJobsStorage"];
const containerName = "eshop-orders";
const fallbackWebhookUrl = process.env["FallbackWebhookUrl"];

const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
const containerClient = blobServiceClient.getContainerClient(containerName);

module.exports = async function (context, orderDetails) {
  context.log('Process message: ', orderDetails);

  const blobContent = JSON.stringify(orderDetails);
  const blobName = `order-${new Date().toISOString()}.json`;
  const blockBlobClient = containerClient.getBlockBlobClient(blobName);

  let retries = 0;
  const maxRetries = 3;  // Maximum number of retries

  while (retries < maxRetries) {
    try {
      await blockBlobClient.upload(blobContent, Buffer.byteLength(blobContent));
      context.log(`Order reserved successfully: ${blobName}`);
      return;  // Exit function upon successful upload
    } catch (err) {
      retries++;
      context.log.warn(`Attempt ${retries} failed to upload blob: ${err.message}`);
      if (retries === maxRetries) {
        context.log.error(`Failed to upload blob after ${maxRetries} attempts.`);
        // Send a request to the fallback webhook
        try {
          const response = await axios.post(fallbackWebhookUrl, {
            message: 'Failed to process order message in OrderReserver function!',
            queueItem: orderDetails,
            error: err.message,
          });

          context.log('Fallback webhook notified about failure:', response.data);
        } catch (axiosError) {
          context.log.error('Error calling fallback webhook:', axiosError.message);
        }
        break;
      }
      // Introducing a delay before retrying might be beneficial
      await delay(1000 * retries);  // Delay increases with each retry
    }
  }
};

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}