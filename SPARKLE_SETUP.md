# Sparkle Setup Guide for Vocorize

This guide will help you set up automatic updates for Vocorize using Sparkle and Cloudflare R2.

## Prerequisites

- A Cloudflare account
- Your app already has Sparkle framework integrated (✅ already done)

## Step 1: Set up Cloudflare R2 Storage

1. **Create R2 Bucket**:
   - Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
   - Navigate to R2 Object Storage
   - Click "Create bucket"
   - Name it something like `vocorize-updates`
   - Choose a region close to your users

2. **Create API Token**:
   - Go to "Manage R2 API tokens"
   - Click "Create API token"
   - Choose "Custom token"
   - Set permissions:
     - Object Read & Write
     - Bucket: Your bucket name
   - Save the Access Key ID and Secret Access Key

## Step 2: Generate Sparkle Private Key

```bash
# Generate a new private key
openssl genrsa -out private_key.pem 2048

# View the key content (you'll need this for .env)
cat private_key.pem
```

**Important**: Copy the entire output including the `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----` lines.

## Step 3: Configure Environment Variables

1. Copy `.env.template` to `.env`:
   ```bash
   cp env.template .env
   ```

2. Edit `.env` and add your Sparkle configuration:
   ```bash
   # Sparkle Update Configuration
   R2_ACCESS_KEY_ID=your-actual-access-key-id
   R2_SECRET_ACCESS_KEY=your-actual-secret-access-key
   R2_ENDPOINT=https://your-account-id.r2.cloudflarestorage.com
   R2_BUCKET=vocorize-updates
   SPARKLE_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----
   MIIEpAIBAAKCAQEA...
   ... (your entire private key) ...
   -----END RSA PRIVATE KEY-----"
   ```

## Step 4: Test the Setup

1. **Build without Sparkle** (to test basic functionality):
   ```bash
   ./build.sh
   ```

2. **Build with Sparkle** (after configuring .env):
   ```bash
   ./build.sh
   ```

You should see:
- ✅ "Sparkle is configured and will be used for updates"
- ✅ "Sparkle appcast entry generated"
- ✅ "Files uploaded to R2 successfully"
- ✅ "Sparkle update published!"

## Step 5: Configure App for Updates

The app is already configured to check for updates. The update feed URL will be:
```
https://your-bucket-name.your-account-id.r2.cloudflarestorage.com/releases/appcast.xml
```

## Troubleshooting

### "Missing Sparkle environment variable" warnings
- Make sure all 5 Sparkle variables are set in your `.env` file
- Check that the private key includes the BEGIN/END lines

### AWS CLI installation fails
- The script will automatically install AWS CLI if needed
- If it fails, install manually: `brew install awscli`

### R2 upload fails
- Verify your R2 credentials are correct
- Check that your bucket exists and is accessible
- Ensure your API token has the right permissions

### Appcast generation fails
- Verify your private key is correctly formatted
- Check that the DMG file was created successfully
- The script will download the `generate_appcast` tool automatically

## Security Notes

- Keep your `.env` file secure and never commit it to git
- The private key is only used temporarily during build and is cleaned up
- R2 credentials should have minimal required permissions

## Manual Updates

If you prefer to handle updates manually:

1. **Skip Sparkle configuration** - just don't set the environment variables
2. **Distribute manually** - upload DMG/ZIP files to your preferred hosting
3. **Users can still check for updates** - they'll just get a "no updates available" message

The app will work perfectly fine without automatic updates - Sparkle is completely optional! 