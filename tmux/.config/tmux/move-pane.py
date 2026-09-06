#!/usr/bin/env python3
"""Move the active pane through the window's layout tree.

tmux reorders panes within a level fine, but join-pane can only ever target a
pane, never a container, so moving a pane between levels is not expressible.
The layout string is the one place the tree is addressable, so this rewrites it
directly and applies the result with select-layout.

"swap" reorders within the current level. "level" changes level: it enters the
neighbour in that direction, or leaves the container when there is no neighbour
to enter.

Usage: move-pane.py {swap|level} {left|right|up|down}
"""

import re
import subprocess
import sys

CELL = re.compile(r"(\d+)x(\d+),(\d+),(\d+)")
AXIS = {"left": "h", "right": "h", "up": "v", "down": "v"}
FORWARD = {"right": True, "down": True, "left": False, "up": False}


class Node:
    def __init__(self, kind, w, h, x, y, kids=None, pid=None):
        self.kind = kind  # "leaf", "h" (side by side), or "v" (stacked)
        self.w, self.h, self.x, self.y = w, h, x, y
        self.kids = kids or []
        self.pid = pid


def parse(body, i=0):
    m = CELL.match(body, i)
    w, h, x, y = map(int, m.groups())
    i = m.end()
    if i < len(body) and body[i] in "{[":
        kind = "h" if body[i] == "{" else "v"
        close = "}" if kind == "h" else "]"
        i += 1
        kids = []
        while True:
            kid, i = parse(body, i)
            kids.append(kid)
            if body[i] != ",":
                break
            i += 1
        return Node(kind, w, h, x, y, kids), i + len(close)
    m = re.compile(r",(\d+)").match(body, i)
    return Node("leaf", w, h, x, y, pid=int(m.group(1))), m.end()


def serialise(node):
    head = "%dx%d,%d,%d" % (node.w, node.h, node.x, node.y)
    if node.kind == "leaf":
        return "%s,%d" % (head, node.pid)
    inner = ",".join(serialise(k) for k in node.kids)
    return head + ("{%s}" if node.kind == "h" else "[%s]") % inner


def checksum(body):
    csum = 0
    for ch in body:
        csum = ((csum >> 1) + ((csum & 1) << 15)) & 0xFFFF
        csum = (csum + ord(ch)) & 0xFFFF
    return "%04x" % csum


def find(node, pid, path=()):
    """Return the list of (container, child_index) pairs leading to pid."""
    if node.kind == "leaf":
        return list(path) if node.pid == pid else None
    for idx, kid in enumerate(node.kids):
        hit = find(kid, pid, path + ((node, idx),))
        if hit is not None:
            return hit
    return None


def tidy(node):
    """Drop containers left with one child and merge same-axis nesting."""
    if node.kind == "leaf":
        return node
    node.kids = [tidy(k) for k in node.kids]
    merged = []
    for kid in node.kids:
        if kid.kind == node.kind:
            merged.extend(kid.kids)
        else:
            merged.append(kid)
    node.kids = merged
    return node.kids[0] if len(node.kids) == 1 else node


def share(total, weights):
    sizes = [max(1, total * w // sum(weights)) for w in weights]
    i = 0
    while sum(sizes) != total and i < 10000:
        j = i % len(sizes)
        if sum(sizes) < total:
            sizes[j] += 1
        elif sizes[j] > 1:
            sizes[j] -= 1
        i += 1
    return sizes


def reflow(node, x, y, w, h):
    node.x, node.y, node.w, node.h = x, y, w, h
    if node.kind == "leaf":
        return
    n = len(node.kids)
    horizontal = node.kind == "h"
    # One character of border sits between each pair of children.
    avail = (w if horizontal else h) - (n - 1)
    sizes = share(avail, [max(k.w if horizontal else k.h, 1) for k in node.kids])
    pos = x if horizontal else y
    for kid, size in zip(node.kids, sizes):
        if horizontal:
            reflow(kid, pos, y, size, h)
        else:
            reflow(kid, x, pos, w, size)
        pos += size + 1


def leaves(node):
    if node.kind == "leaf":
        return [node.pid]
    return [pid for kid in node.kids for pid in leaves(kid)]


def move(root, pid, op, direction):
    """Rewrite the tree in place. Returns False when the move is not possible."""
    want, forward = AXIS[direction], FORWARD[direction]
    path = find(root, pid, ())
    if not path:
        return False
    parent, idx = path[-1]
    leaf = parent.kids[idx]

    if op == "swap":
        for node, child in reversed(path):
            if node.kind != want:
                continue
            j = child + (1 if forward else -1)
            if not 0 <= j < len(node.kids):
                return False
            node.kids[child], node.kids[j] = node.kids[j], node.kids[child]
            return True
        return False

    # "level": enter the neighbour when there is one, otherwise leave the
    # container. Which of the two applies is fixed by where the pane sits in the
    # tree, so they do not need separate keys.
    if parent.kind == want:
        j = idx + (1 if forward else -1)
        if 0 <= j < len(parent.kids):
            target = parent.kids[j]
            parent.kids.pop(idx)
            if target.kind == "leaf":
                # A leaf has no inside, so open one perpendicular to the travel.
                perp = "v" if want == "h" else "h"
                clone = Node("leaf", target.w, target.h, target.x, target.y,
                             pid=target.pid)
                new = Node(perp, target.w, target.h, target.x, target.y,
                           kids=[clone, leaf])
                parent.kids[parent.kids.index(target)] = new
            elif target.kind == want:
                target.kids.insert(0 if forward else len(target.kids), leaf)
            else:
                target.kids.append(leaf)
            return True

    # Land beside the nearest ancestor that runs along this axis.
    for node, child in reversed(path[:-1]):
        if node.kind == want:
            parent.kids.pop(idx)
            node.kids.insert(child + (1 if forward else 0), leaf)
            return True
    if parent is root and root.kind == want:
        return False
    parent.kids.pop(idx)
    inner = Node(root.kind, root.w, root.h, root.x, root.y, kids=root.kids)
    root.kind = want
    root.kids = [inner, leaf] if forward else [leaf, inner]
    return True


def tmux(*args):
    return subprocess.run(("tmux",) + args, capture_output=True,
                          text=True).stdout.strip()


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: move-pane.py {swap|level} {left|right|up|down}")
    op, direction = sys.argv[1], sys.argv[2]
    if op not in ("swap", "level") or direction not in AXIS:
        sys.exit("usage: move-pane.py {swap|level} {left|right|up|down}")

    pane = tmux("display-message", "-p", "#{pane_id}")
    layout = tmux("display-message", "-p", "#{window_layout}")
    order = tmux("list-panes", "-F", "#{pane_id}").split()
    if len(order) < 2:
        return

    root = parse(layout.split(",", 1)[1])[0]
    if not move(root, int(pane[1:]), op, direction):
        return
    root = tidy(root)
    reflow(root, 0, 0, root.w, root.h)

    # select-layout fills cells in window order, ignoring the ids in the string,
    # so the panes have to be permuted into that order first.
    want = ["%%%d" % pid for pid in leaves(root)]
    for i, target in enumerate(want):
        if order[i] != target:
            j = order.index(target)
            tmux("swap-pane", "-d", "-s", order[i], "-t", order[j])
            order[i], order[j] = order[j], order[i]

    body = serialise(root)
    tmux("select-layout", "%s,%s" % (checksum(body), body))
    tmux("select-pane", "-t", pane)


if __name__ == "__main__":
    main()
