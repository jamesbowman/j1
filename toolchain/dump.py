import sys
import array

def hexdump(s):
    def toprint(c):
        if 32 <= ord(c) < 127:
            return c
        else:
            return "."
    def hexline(i, s):
        return ("%04x: " % i + " ".join(["%02x" % ord(c) for c in s]).ljust(52) +
                "|" +
                "".join([toprint(c) for c in s]).ljust(16) +
                "|")
    return "\n".join([hexline(i, s[i:i+16]) for i in range(0, len(s), 16)])

pgm = array.array('H', [int(l, 16) for l in open(sys.argv[1])])

while pgm[-1] == 0:
    pgm = pgm[:-1]
s = pgm.tostring()
print
print hexdump(s)

link = [w for w in pgm[::-1] if w][0]
words = []
while link:
    name = s[link + 2:]
    c = ord(name[0])
    name = name[1:1+c]
    print "%04x %s" % (link, name)
    assert not name in words
    words.append(name)
    link = pgm[link / 2]
print len(words), " ".join(words)
print "program size %d/%d" % (len(pgm), 1024)
