// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'editable_box.dart';

/// Registry of all [RenderEditableBox]es inside a [ZefyrEditableText].
///
/// Provides access to all currently active [RenderEditableBox]
/// instances of a [ZefyrEditableText].
///
/// Use [boxForTextOffset] or [boxForGlobalPoint] to retrieve a
/// specific box.
///
/// The [addBox], [removeBox] and [markDirty] are intended to be
/// only used by [RenderEditableBox] objects to register with a rendering
/// context.
///
/// ### Life cycle details
///
/// When a box object is attached to rendering pipeline it registers
/// itself with a render scope by calling [addBox]. At this point the context
/// treats this object as "dirty" and query methods like [boxForTextOffset]
/// still exclude this object from returned results.
///
/// When this box considers itself initialized it calls [markDirty] with
/// `isDirty` set to `false` which activates it. At this point query methods
/// include this object in results.
///
/// When a box is rebuilt it may deactivate itself by calling [markDirty]
/// again.
///
/// When a box is detached from rendering pipeline it unregisters
/// itself by calling [removeBox].
class ZefyrRenderContext extends ChangeNotifier {
  final Set<RenderEditableBox> _dirtyBoxes = new Set();
  final Set<RenderEditableBox> _activeBoxes = new Set();

  Set<RenderEditableBox> get dirty => _dirtyBoxes;
  Set<RenderEditableBox> get active => _activeBoxes;

  bool _disposed = false;

  /// Adds [box] to this context. The box is considered "dirty" at
  /// this point and is not included in query results of `boxFor*`
  /// methods.
  void addBox(RenderEditableBox box) {
    assert(!_disposed);
    _dirtyBoxes.add(box);
  }

  /// Removes [box] from this render context.
  void removeBox(RenderEditableBox box) {
    assert(!_disposed);
    _dirtyBoxes.remove(box);
    _activeBoxes.remove(box);
    notifyListeners();
  }

  void markDirty(RenderEditableBox box, bool isDirty) {
    assert(!_disposed);

    var collection = isDirty ? _dirtyBoxes : _activeBoxes;
    if (collection.contains(box)) return;

    if (isDirty) {
      _activeBoxes.remove(box);
      _dirtyBoxes.add(box);
    } else {
      _dirtyBoxes.remove(box);
      _activeBoxes.add(box);
    }
    notifyListeners();
  }

  /// Returns box containing character at specified document [offset].
  RenderEditableBox boxForTextOffset(int offset) {
    assert(!_disposed);
    return _activeBoxes.firstWhere(
      (p) => p.node.containsOffset(offset),
      orElse: _null,
    );
  }

  /// Returns box located at specified global [point] on the screen or
  /// `null`.
  RenderEditableBox boxForGlobalPoint(Offset point) {
    assert(!_disposed);
    return _activeBoxes.firstWhere((p) {
      final localPoint = p.globalToLocal(point);
      return p.size.contains(localPoint);
    }, orElse: _null);
  }

  static Null _null() => null;

  @override
  void dispose() {
    _disposed = true;
    _activeBoxes.clear();
    _dirtyBoxes.clear();
    super.dispose();
  }

  @override
  void notifyListeners() {
    /// Ensures listeners are not notified during rendering phase where they
    /// cannot react by updating their state or rebuilding.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      super.notifyListeners();
    });
  }
}
