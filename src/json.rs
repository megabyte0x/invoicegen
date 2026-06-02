use std::collections::BTreeMap;

#[derive(Clone, Debug, PartialEq)]
pub enum JsonValue {
    Null,
    Bool(bool),
    Number(String),
    String(String),
    Array(Vec<JsonValue>),
    Object(BTreeMap<String, JsonValue>),
}

impl JsonValue {
    pub fn as_object(&self) -> Option<&BTreeMap<String, JsonValue>> {
        match self {
            JsonValue::Object(value) => Some(value),
            _ => None,
        }
    }

    pub fn as_array(&self) -> Option<&[JsonValue]> {
        match self {
            JsonValue::Array(value) => Some(value),
            _ => None,
        }
    }

    pub fn as_str(&self) -> Option<&str> {
        match self {
            JsonValue::String(value) => Some(value),
            _ => None,
        }
    }

    pub fn as_i64(&self) -> Option<i64> {
        match self {
            JsonValue::Number(value) => value.parse().ok(),
            _ => None,
        }
    }

    pub fn as_f64(&self) -> Option<f64> {
        match self {
            JsonValue::Number(value) => value.parse().ok(),
            _ => None,
        }
    }
}

pub fn parse(input: &str) -> Result<JsonValue, String> {
    let mut parser = Parser {
        input: input.as_bytes(),
        pos: 0,
    };
    let value = parser.parse_value()?;
    parser.skip_whitespace();
    if parser.pos != parser.input.len() {
        return Err(format!("unexpected trailing JSON at byte {}", parser.pos));
    }
    Ok(value)
}

pub fn stringify_pretty(value: &JsonValue) -> String {
    let mut output = String::new();
    write_pretty(value, 0, &mut output);
    output.push('\n');
    output
}

pub fn object(entries: impl IntoIterator<Item = (String, JsonValue)>) -> JsonValue {
    JsonValue::Object(entries.into_iter().collect())
}

pub fn string(value: impl Into<String>) -> JsonValue {
    JsonValue::String(value.into())
}

pub fn number(value: impl ToString) -> JsonValue {
    JsonValue::Number(value.to_string())
}

struct Parser<'a> {
    input: &'a [u8],
    pos: usize,
}

impl Parser<'_> {
    fn parse_value(&mut self) -> Result<JsonValue, String> {
        self.skip_whitespace();
        match self.peek() {
            Some(b'n') => self.parse_literal(b"null", JsonValue::Null),
            Some(b't') => self.parse_literal(b"true", JsonValue::Bool(true)),
            Some(b'f') => self.parse_literal(b"false", JsonValue::Bool(false)),
            Some(b'"') => self.parse_string().map(JsonValue::String),
            Some(b'[') => self.parse_array(),
            Some(b'{') => self.parse_object(),
            Some(b'-' | b'0'..=b'9') => self.parse_number().map(JsonValue::Number),
            Some(byte) => Err(format!(
                "unexpected JSON byte {:?} at byte {}",
                byte as char, self.pos
            )),
            None => Err("unexpected end of JSON".to_string()),
        }
    }

    fn parse_literal(&mut self, expected: &[u8], value: JsonValue) -> Result<JsonValue, String> {
        if self.input.get(self.pos..self.pos + expected.len()) == Some(expected) {
            self.pos += expected.len();
            Ok(value)
        } else {
            Err(format!("invalid literal at byte {}", self.pos))
        }
    }

    fn parse_string(&mut self) -> Result<String, String> {
        self.expect(b'"')?;
        let mut output = String::new();
        while let Some(byte) = self.next() {
            match byte {
                b'"' => return Ok(output),
                b'\\' => {
                    let escaped = self
                        .next()
                        .ok_or_else(|| "unterminated escape in JSON string".to_string())?;
                    match escaped {
                        b'"' => output.push('"'),
                        b'\\' => output.push('\\'),
                        b'/' => output.push('/'),
                        b'b' => output.push('\u{0008}'),
                        b'f' => output.push('\u{000c}'),
                        b'n' => output.push('\n'),
                        b'r' => output.push('\r'),
                        b't' => output.push('\t'),
                        b'u' => {
                            let code = self.parse_hex4()?;
                            let ch = char::from_u32(code)
                                .ok_or_else(|| format!("invalid unicode escape {code:x}"))?;
                            output.push(ch);
                        }
                        _ => {
                            return Err(format!(
                                "invalid escape {:?} at byte {}",
                                escaped as char, self.pos
                            ))
                        }
                    }
                }
                0x00..=0x1f => {
                    return Err(format!("control character in string at byte {}", self.pos));
                }
                _ => {
                    let start = self.pos - 1;
                    let width = utf8_char_width(byte)?;
                    let end = start + width;
                    if end > self.input.len() {
                        return Err("unterminated utf-8 sequence in string".to_string());
                    }
                    let text = std::str::from_utf8(&self.input[start..end])
                        .map_err(|error| error.to_string())?;
                    output.push_str(text);
                    self.pos = end;
                }
            }
        }
        Err("unterminated JSON string".to_string())
    }

    fn parse_hex4(&mut self) -> Result<u32, String> {
        let mut value = 0_u32;
        for _ in 0..4 {
            let byte = self
                .next()
                .ok_or_else(|| "unterminated unicode escape".to_string())?;
            value = value * 16
                + match byte {
                    b'0'..=b'9' => u32::from(byte - b'0'),
                    b'a'..=b'f' => u32::from(byte - b'a' + 10),
                    b'A'..=b'F' => u32::from(byte - b'A' + 10),
                    _ => return Err(format!("invalid unicode escape byte {:?}", byte as char)),
                };
        }
        Ok(value)
    }

    fn parse_array(&mut self) -> Result<JsonValue, String> {
        self.expect(b'[')?;
        let mut values = Vec::new();
        loop {
            self.skip_whitespace();
            if self.consume(b']') {
                break;
            }
            values.push(self.parse_value()?);
            self.skip_whitespace();
            if self.consume(b']') {
                break;
            }
            self.expect(b',')?;
        }
        Ok(JsonValue::Array(values))
    }

    fn parse_object(&mut self) -> Result<JsonValue, String> {
        self.expect(b'{')?;
        let mut values = BTreeMap::new();
        loop {
            self.skip_whitespace();
            if self.consume(b'}') {
                break;
            }
            let key = self.parse_string()?;
            self.skip_whitespace();
            self.expect(b':')?;
            let value = self.parse_value()?;
            values.insert(key, value);
            self.skip_whitespace();
            if self.consume(b'}') {
                break;
            }
            self.expect(b',')?;
        }
        Ok(JsonValue::Object(values))
    }

    fn parse_number(&mut self) -> Result<String, String> {
        let start = self.pos;
        self.consume(b'-');
        match self.peek() {
            Some(b'0') => {
                self.pos += 1;
            }
            Some(b'1'..=b'9') => {
                self.pos += 1;
                while matches!(self.peek(), Some(b'0'..=b'9')) {
                    self.pos += 1;
                }
            }
            _ => return Err(format!("invalid number at byte {start}")),
        }
        if self.consume(b'.') {
            let fraction_start = self.pos;
            while matches!(self.peek(), Some(b'0'..=b'9')) {
                self.pos += 1;
            }
            if self.pos == fraction_start {
                return Err(format!("invalid number fraction at byte {start}"));
            }
        }
        if matches!(self.peek(), Some(b'e' | b'E')) {
            self.pos += 1;
            if matches!(self.peek(), Some(b'+' | b'-')) {
                self.pos += 1;
            }
            let exponent_start = self.pos;
            while matches!(self.peek(), Some(b'0'..=b'9')) {
                self.pos += 1;
            }
            if self.pos == exponent_start {
                return Err(format!("invalid number exponent at byte {start}"));
            }
        }
        Ok(String::from_utf8_lossy(&self.input[start..self.pos]).into_owned())
    }

    fn skip_whitespace(&mut self) {
        while matches!(self.peek(), Some(b' ' | b'\n' | b'\r' | b'\t')) {
            self.pos += 1;
        }
    }

    fn expect(&mut self, expected: u8) -> Result<(), String> {
        if self.consume(expected) {
            Ok(())
        } else {
            Err(format!(
                "expected {:?} at byte {}",
                expected as char, self.pos
            ))
        }
    }

    fn consume(&mut self, expected: u8) -> bool {
        if self.peek() == Some(expected) {
            self.pos += 1;
            true
        } else {
            false
        }
    }

    fn next(&mut self) -> Option<u8> {
        let byte = self.peek()?;
        self.pos += 1;
        Some(byte)
    }

    fn peek(&self) -> Option<u8> {
        self.input.get(self.pos).copied()
    }
}

fn utf8_char_width(byte: u8) -> Result<usize, String> {
    match byte {
        0x00..=0x7f => Ok(1),
        0xc2..=0xdf => Ok(2),
        0xe0..=0xef => Ok(3),
        0xf0..=0xf4 => Ok(4),
        _ => Err(format!("invalid utf-8 byte {byte:#x}")),
    }
}

fn write_pretty(value: &JsonValue, indent: usize, output: &mut String) {
    match value {
        JsonValue::Null => output.push_str("null"),
        JsonValue::Bool(value) => output.push_str(if *value { "true" } else { "false" }),
        JsonValue::Number(value) => output.push_str(value),
        JsonValue::String(value) => write_json_string(value, output),
        JsonValue::Array(values) => {
            if values.is_empty() {
                output.push_str("[]");
                return;
            }
            output.push('[');
            output.push('\n');
            for (index, value) in values.iter().enumerate() {
                output.push_str(&" ".repeat(indent + 2));
                write_pretty(value, indent + 2, output);
                if index + 1 != values.len() {
                    output.push(',');
                }
                output.push('\n');
            }
            output.push_str(&" ".repeat(indent));
            output.push(']');
        }
        JsonValue::Object(values) => {
            if values.is_empty() {
                output.push_str("{}");
                return;
            }
            output.push('{');
            output.push('\n');
            for (index, (key, value)) in values.iter().enumerate() {
                output.push_str(&" ".repeat(indent + 2));
                write_json_string(key, output);
                output.push_str(": ");
                write_pretty(value, indent + 2, output);
                if index + 1 != values.len() {
                    output.push(',');
                }
                output.push('\n');
            }
            output.push_str(&" ".repeat(indent));
            output.push('}');
        }
    }
}

fn write_json_string(value: &str, output: &mut String) {
    output.push('"');
    for ch in value.chars() {
        match ch {
            '"' => output.push_str("\\\""),
            '\\' => output.push_str("\\\\"),
            '\n' => output.push_str("\\n"),
            '\r' => output.push_str("\\r"),
            '\t' => output.push_str("\\t"),
            '\u{0008}' => output.push_str("\\b"),
            '\u{000c}' => output.push_str("\\f"),
            '\u{0000}'..='\u{001f}' => {
                output.push_str(&format!("\\u{:04x}", ch as u32));
            }
            _ => output.push(ch),
        }
    }
    output.push('"');
}
