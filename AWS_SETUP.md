# AWS S3 & Imgix Setup Guide

## 🚀 Quick Setup Checklist

### 1. **AWS S3 Configuration**

Required environment variables for image uploads:

```bash
AWS_REGION=us-west-2
AWS_ACCESS_KEY_ID=your_aws_access_key_id
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
AWS_S3_BUCKET=guahan-grocer-images
```

### 2. **Create S3 Bucket**

1. Go to AWS S3 Console
2. Create new bucket: `guahan-grocer-images`
3. **IMPORTANT**: Set bucket policy for public read access:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::guahan-grocer-images/*"
        }
    ]
}
```

4. Enable CORS for web uploads:

```json
[
    {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
        "AllowedOrigins": ["*"],
        "ExposeHeaders": []
    }
]
```

### 3. **Create IAM User**

1. Go to AWS IAM Console
2. Create new user: `guahan-grocer-s3-user`
3. Attach policy with S3 permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::guahan-grocer-images/*"
        }
    ]
}
```

4. Generate access keys and save them securely

### 4. **Imgix CDN Setup (Optional but Recommended)**

1. Sign up at [imgix.com](https://imgix.com)
2. Create new source pointing to your S3 bucket
3. Add environment variable:

```bash
IMGIX_DOMAIN=your-domain.imgix.net
```

Benefits:
- **Fast CDN delivery** worldwide
- **Automatic image optimization** (WebP, compression)
- **On-the-fly resizing** for thumbnails
- **Better performance** for mobile apps

## 🧪 Testing Image Uploads

### Test with cURL:

```bash
# 1. Login as admin
TOKEN=$(curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"password"}' \
  -s | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

# 2. Upload image to product
curl -X POST http://localhost:3000/api/v1/products/1/upload_image \
  -H "Authorization: Bearer $TOKEN" \
  -F "image=@/path/to/your/image.jpg"

# 3. Check product with image
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/v1/products/1
```

### Expected Response:

```json
{
  "id": "1",
  "name": "Fresh Bananas",
  "imageUrl": "https://guahan-grocer-images.s3.us-west-2.amazonaws.com/products/1/1640995200.jpg",
  "images": {
    "thumbnail": "https://your-domain.imgix.net/products/1/1640995200.jpg?w=150&h=150&fit=crop",
    "medium": "https://your-domain.imgix.net/products/1/1640995200.jpg?w=400&h=400&fit=crop",
    "large": "https://your-domain.imgix.net/products/1/1640995200.jpg?w=800&h=600&fit=crop",
    "original": "https://your-domain.imgix.net/products/1/1640995200.jpg"
  }
}
```

## 🔒 Security Notes

- ✅ Images stored in structured S3 paths: `products/{product_id}/{timestamp}.{ext}`
- ✅ File type validation (JPEG, PNG, WebP only)
- ✅ File size limits (5MB max)
- ✅ Filename sanitization
- ✅ Public read access for product images
- ✅ Admin-only upload permissions

## 📱 Frontend Integration

Your React Native app will receive image URLs in this format:

```typescript
interface Product {
  id: string;
  name: string;
  imageUrl: string | null;
  images: {
    thumbnail: string;
    medium: string;
    large: string;
    original: string;
  } | null;
}
```

Use `images.thumbnail` for lists, `images.medium` for detail views!

## 💰 Cost Estimation

- **S3 Storage**: ~$0.023/GB/month
- **S3 Requests**: ~$0.0004/1000 requests  
- **Imgix**: Free tier: 1GB bandwidth/month
- **Total for 100 products with images**: ~$2-5/month

## 🚨 Troubleshooting

### Common Issues:

1. **"Missing S3 configuration"** → Check environment variables
2. **"Access denied"** → Verify IAM permissions and bucket policy
3. **"Invalid file type"** → Only JPEG, PNG, WebP allowed
4. **"File too large"** → 5MB maximum file size
5. **Images don't load** → Check bucket public access policy

### Debug Commands:

```bash
# Check environment variables
rails console
> ENV['AWS_S3_BUCKET']
> ENV['AWS_ACCESS_KEY_ID']

# Test S3 connection
> S3Uploader.validate_configuration!

# Test image upload
> product = Product.first
> # Upload test image file
``` 