package com.tatakikun.android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ClipHistoryTest {
    private class Memory : ClipHistory.Store {
        var saved: ClipHistory.Saved? = null
        override fun load() = saved
        override fun save(saved: ClipHistory.Saved) { this.saved = saved }
    }

    @Test fun newestFirstWithoutDuplicates() {
        val h = ClipHistory(Memory())
        h.add("one"); h.add("two"); h.add("three")
        assertEquals(listOf("three", "two", "one"), h.items)
        h.add("one")
        assertEquals("copying again moves it to the top", listOf("one", "three", "two"), h.items)
        h.add("  \n"); h.add("")
        assertEquals("blank text is left out", 3, h.items.size)
        h.add("x".repeat(ClipHistory.LONGEST + 1))
        assertEquals("very long text is left out", 3, h.items.size)
    }

    @Test fun oldestDropOff() {
        val h = ClipHistory(Memory())
        repeat(ClipHistory.LIMIT + 5) { h.add("item $it") }
        assertEquals(ClipHistory.LIMIT, h.items.size)
        assertEquals("item ${ClipHistory.LIMIT + 4}", h.items.first())
        assertEquals("item 5", h.items.last())
    }

    @Test fun removeAndClear() {
        val h = ClipHistory(Memory())
        h.add("a"); h.add("b"); h.add("c")
        h.remove(1)
        assertEquals(listOf("c", "a"), h.items)
        h.remove(9)
        assertEquals(listOf("c", "a"), h.items)
        h.clear()
        assertEquals(emptyList<String>(), h.items)
        assertNull(h.chip())
    }

    @Test fun chip() {
        val h = ClipHistory(Memory())
        val t = 1_000_000L
        assertNull(h.chip(t))
        h.add("hello", t)
        assertEquals("hello", h.chip(t + 5_000))
        assertNull("the chip goes away after a while", h.chip(t + ClipHistory.CHIP_MS + 1))
        h.dismissChip()
        assertNull(h.chip(t))
        assertEquals("pasting from the chip keeps the copy in the list", listOf("hello"), h.items)
        h.add("world", t)
        h.remove(0)
        assertNull("a deleted copy is not offered", h.chip(t))
    }

    @Test fun keptAcrossRestarts() {
        val store = Memory()
        val t = System.currentTimeMillis()
        ClipHistory(store).add("first", t)
        ClipHistory(store).add("second", t)
        val again = ClipHistory(store)
        assertEquals(listOf("second", "first"), again.items)
        assertEquals("second", again.chip(t))
    }
}
