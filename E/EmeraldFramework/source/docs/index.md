# EmeraldFramework

Object-oriented Framework for World of Warcraft.

## Features

- Classes
- Properties
- Bindings
- Signals and Slots Connections
- Destructible UI elements with native frames recycling
- PixelPerfect UI

## Class Implementation

EmeraldFramework implements classes with constructor and single inheritance.

## Properties

Properties can be attached to instances of [`Object`](/API/Item.md) or derived classes.

A property usually have an associated signal which triggers when the property's value is changed.

## Bindings

A binding wraps a function, and re-execute in whenever a property accessed during last evaluation changes its value.

It is possible to assign a binding to a property, having its value update automatically. Calls are protected (see [Signals and Slots Connections](/#signals-and-slots-connections)).

## Signals and Slots Connections

Signals are usually attached to [`Object`](/API/Item.md)s and can be connected to slots, which are just functions or functions of other objects. When a signal is triggerd, all connected slots are called, arguments passed to the signal are forwarded to the slots. Connection's callbacks are calls are protected (invoked through `pcall`, `EFrame.debug` can be set to use `xpcall`)

### Queued connections

Connections to objects can be queued so they're executed when the control returns to the event loop. Connections can be set as queued by setting `.queued = true`

### Out of combat connections

Connections to objects can be queued so they're executed only when there is no combat restriction. Connections can be set as out of combat by setting `.nocombat = true`

## UI Elements

EmeraldFramework provides UI components implemented though classes, properties and signals. They range from basic UI elements like [`Item`](/API/Item.md)s (base class of all UI elements) to high-level ones. It also features controls for user input and layouts.

UI elements can be destroyed, the underlying native frames are recycled to be re-used when new UI elements are created. Please keep 'em clean.

The [`root`](/API/Item.md#root) item is the default parent for UI elements, it's scaled to be PixelPerfect to make the default theme look good. If need a different scale, the Blizzlike theme will look better.
