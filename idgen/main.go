package idgen

import (
	"fmt"

	"github.com/yuin/goldmark/ast"
	"github.com/yuin/goldmark/parser"
	"github.com/yuin/goldmark/util"
)

// GitHub like ID generator for goldmark
//
// See also:
// - https://github.com/yuin/goldmark/blob/master/parser/parser.go#L65
// - https://github.com/yuin/goldmark/issues/56#issuecomment-562963529

type ids struct {
	values map[string]bool
}

// New creates ID Generator like GitHub's.
// ```
// ctx := parser.NewContext(parser.WithIDs(idgen.New()))
// markdown := goldmark.New(WithParserOptions(parser.WithAutoHeadingID()))
// markdown.Convert(source, &b, parser.WithContext(ctx))
// ```
func New() parser.IDs {
	return &ids{
		values: map[string]bool{},
	}
}

func (s *ids) Generate(value []byte, kind ast.NodeKind) []byte {
	value = util.TrimLeftSpace(value)
	value = util.TrimRightSpace(value)
	result := []byte{}
	for i := 0; i < len(value); {
		v := value[i]
		l := util.UTF8Len(v)
		if util.IsAlphaNumeric(v) {
			if 'A' <= v && v <= 'Z' {
				v += 'a' - 'A'
			}
			result = append(result, v)
		} else if util.IsSpace(v) || v == '-' || v == '_' {
			result = append(result, '-')
		} else {
			for j := 0; j < int(l); j++ {
				v := value[i+j]
				result = append(result,
					'%',
					"0123456789ABCDEF"[v>>4],
					"0123456789ABCDEF"[v&15])
			}
		}
		i += int(l)
	}
	if len(result) == 0 {
		if kind == ast.KindHeading {
			result = []byte("xheading")
		} else {
			result = []byte("id")
		}
	}
	if _, ok := s.values[util.BytesToReadOnlyString(result)]; !ok {
		s.values[util.BytesToReadOnlyString(result)] = true
		return result
	}
	for i := 1; ; i++ {
		newResult := fmt.Sprintf("%s-%d", result, i)
		if _, ok := s.values[newResult]; !ok {
			s.values[newResult] = true
			return []byte(newResult)
		}

	}
}

func (s *ids) Put(value []byte) {
	s.values[util.BytesToReadOnlyString(value)] = true
}
