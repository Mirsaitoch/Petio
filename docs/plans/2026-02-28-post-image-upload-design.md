# Post Image Upload — Design

**Date:** 2026-02-28
**Status:** Approved

## Summary

Add the ability to attach one photo to a post when creating it. The image is sent via multipart/form-data together with the post data. The server returns the created Post with an image URL.

## Decisions

- **Max images per post:** 1
- **Sources:** Gallery + Camera
- **Upload flow:** Upload + post creation in a single multipart request
- **Approach:** Reuse and adapt existing `AvatarPickerButton` infrastructure

## Architecture

Changes to 4 files:

| File | Change |
|------|--------|
| `Design/ImagePickerView.swift` | Add `PostImagePickerButton` — like `AvatarPickerButton` but holds `UIImage` in memory (no local save) |
| `Features/Feed/NewPostSheet.swift` | Add image picker button + selected photo preview with remove option |
| `Core/Network/HTTPAPIClient.swift` | Add `uploadPostWithImage(_:image:)` multipart method |
| `Services/AppState.swift` | Update `addPost(_:image:)` to pass `UIImage?` to the appropriate API method |

## UI

```
┌─────────────────────────────────┐
│  Новый пост                [✕]  │
│                                 │
│  [Собаки ▾]                     │
│                                 │
│  ┌───────────────────────────┐  │
│  │  Что у вас произошло?    │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌──────┐                       │
│  │  +   │  ← tap: gallery/cam  │
│  └──────┘                       │
│                                 │
│  [selected photo preview]       │
│  (✕ button to remove)           │
│                                 │
│         [Опубликовать]          │
└─────────────────────────────────┘
```

## Data Flow

1. User picks photo → `UIImage` stored in `@State var selectedImage: UIImage?`
2. Tap "Опубликовать" → `AppState.addPost(post, image: selectedImage)`
3. If image present: `api.uploadPostWithImage(post, image)` — multipart/form-data
4. If no image: `api.addPost(post)` — plain JSON (unchanged)
5. Server returns `Post` with `image: String?` URL populated

## Network Request (multipart)

```
POST /posts
Content-Type: multipart/form-data; boundary=<uuid>

--boundary
Content-Disposition: form-data; name="image"; filename="photo.jpg"
Content-Type: image/jpeg
<binary JPEG, quality 0.8>

--boundary
Content-Disposition: form-data; name="content"
<post text>

--boundary
Content-Disposition: form-data; name="club"
<club name>

--boundary--
```

## Image Handling

- Compress to JPEG quality 0.8 before upload
- No local file save (unlike avatars)
- `UIImage` held in memory only until post is published
