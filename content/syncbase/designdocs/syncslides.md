= yaml =
title: SyncSlides
layout: syncbase
toc: false
= yaml =

# Functionality
Peer-to-peer slide presentation.  Allows audience to ask questions.
Presenter can delegate control of the presentation to an audience member temporarily.

## Key Behaviors
* Distribute slide content to audience
* Slide images are blobs
* Presenter’s location gets synced to audience
* Audience can explore slides independently of presenter
* Audience can ask questions
* Presenter can delegate control of the presentation to an audience member
* Presenter and audience can take notes that are shared only with that user’s devices

# Schema

## Data Types
```Go
// VDeck is the metadata for a set of slides.
type VDeck struct {
  Title string
  Thumbnail []byte
}

// VSlide contains the image content for the slide.
type VSlide struct {
  // A low-res version of the image stored as JPG.
  Thumbnail []byte
  // A high-res version of the image stored as JPG.
  Fullsize Blobref
}

// VNote contains private-to-the-user notes for a specific slide.
type VNote struct {
  Text string
}

// VPresentation represents a live display of a VDeck.
type VPresentation struct {
  // The unique ID of the deck used in this presentation
  DeckId String
  // Owner is responsible for advertising the presentation and has full
  // control of it.
  Owner VPerson
  // Driver represents who has control of the presentation.  Usually, it is
  // the presenter, but the presenter can give control to an audience member
  // by changing this field.
  Driver VPerson
}

// VPerson represents either an audience member or the presenter.
type VPerson struct {
  Blessing string
  // The person's full name.
  Name string
}

// VCurrentSlide contains state for the live presentation.  It is separate
// from the VPresentation so that the presenter can temporarily delegate
// control of the VCurrentSlide without giving up control of the entire
// presentation.
type VCurrentSlide struct {
  // The number of the slide that the presenter is talking about.
  SlideNum int32
  // In the future, we could add markup/doodles here.  That markup would be
  // transient if stored here.  Maybe better to put it in a separate row...
}

// VQuestion represents a member of the audience asking a question of the
// presenter. TODO(kash): Add support for the user to type in their question.
// Right now, they need to ask their question verbally.
type VQuestion struct {
  // The person who asked the question.
  Questioner VPerson
  // Time when the question was asked in milliseconds since the epoch.
  Time int64
  // Track whether this question has been answered.
  Answered bool
}

// VSession represents UI state that most apps would consider to be ephemeral.
// By storing it in Syncbase, we can resume a session on another device.
// It also simplifies the Android implementation because we don't have to store
// all of this state in a Bundle for each Activity/Fragment.
type VSession struct {
  DeckId string
  PresentationId string
  // When the user is not driving the presentation, he can go forward/back in
  // the deck on his own.  A value of -1 means the user is following the
  // driver of the presentation.
  LocalSlide int32
  // The time that this session was last used in milliseconds since the epoch.
  // This field allows us to find the most recently used session and prompt
  // the user to resume it.
  LastTouched int64
}
```

## Organization

```
Collection <deckId>
  deck → VDeck
  slides/1 → VSlide
  slides/2 → VSlide
  …

Collection <presentationId>
  presentation → VPresentation
  questions/<uuid> → VQuestion
  questions/<uuid> → VQuestion

Collection <presentationId + “control”>
  currentSlides → VCurrentSlide
  Collection <userblessing + “ui”>
  <sessionId> → VSession
```

# Syncing and permissions

* There is a separate collection for the deck so that it can be used in multiple presentations.
* The presentation collection is writable by the presenter and read-only for the audience.
* The <presentationId + “control”> collection is read-write for the presenter and read-only for the audience.  When the presenter wants to give control to an audience member, the presenter changes the ACL on this collection appropriately.
* Without fine-grained ACLs, it is difficult to use sync to ask questions.  Either we fully trust the audience and allow complete access to all questions or we use RPCs to send the questions to the presenter.  Seems like RPCs is the better way to go

# Conflicts
No conflicts expected, but last-one-wins would probably work.