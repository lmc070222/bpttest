#include "Bplustree.hpp"
#include <iostream>
using namespace std;
#include <cstring>
#pragma pack(push, 1)
struct String64 {
  char data[64];
  String64() { memset(data, 0, 64); }
  String64(const char *s) {
    strncpy(data, s, 63);
    data[63] = '\0';
  }
  String64 &operator=(const String64 &other) {
    memcpy(data, other.data, 64);
    return *this;
  }
  bool operator<(const String64 &other) const {
    return strcmp(data, other.data) < 0;
  }
  bool operator>(const String64 &other) const {
    return strcmp(data, other.data) > 0;
  }
  bool operator>=(const String64 &other) const {
    return strcmp(data, other.data) >= 0;
  }
  bool operator<=(const String64 &other) const {
    return strcmp(data, other.data) <= 0;
  }
  bool operator==(const String64 &other) const {
    return strcmp(data, other.data) == 0;
  }
  bool operator!=(const String64 &other) const {
    return strcmp(data, other.data) != 0;
  }
};
#pragma pack(pop)
static void merge(sjtu::vector<int> &v, sjtu::vector<int> &tmp, int l, int m,
                  int r) {
  int i = l, j = m, k = l;
  while (i < m && j < r) {
    tmp[k++] = (v[i] <= v[j]) ? v[i++] : v[j++];
  }
  while (i < m)
    tmp[k++] = v[i++];
  while (j < r)
    tmp[k++] = v[j++];
  for (int t = l; t < r; ++t)
    v[t] = tmp[t];
}
static void merge_sort_rec(sjtu::vector<int> &v, sjtu::vector<int> &tmp, int l,
                           int r) {
  if (r - l <= 1)
    return;
  int m = l + (r - l) / 2;
  merge_sort_rec(v, tmp, l, m);
  merge_sort_rec(v, tmp, m, r);
  merge(v, tmp, l, m, r);
}
void merge_sort(sjtu::vector<int> &v) {
  if (v.size() <= 1)
    return;
  sjtu::vector<int> tmp;
  for (int i = 0; i < v.size(); i++)
    tmp.push_back(0);
  merge_sort_rec(v, tmp, 0, v.size());
}
int main() {
  int n;
  cin >> n;
  char a[64];
  int value;
  Bplustree<String64, int, 50> tree;
  string order;
  for (int i = 1; i <= n; i++) {
    cin >> order;
    if (order == "insert") {
      cin >> a >> value;
      String64 index(a);
      tree.Insert(index, value);
    } else if (order == "delete") {
      cin >> a >> value;
      String64 index(a);
      tree.deletenode(index, value);
    } else if (order == "find") {
      cin >> a;
      String64 index(a);
      sjtu::vector<int> ans = tree.find(index);
      if (ans.size() != 0) {
        merge_sort(ans);
        for (int i = 0; i < ans.size(); i++) {
          std::cout << ans[i] << ' ';
        }
        std::cout << std::endl;
      } else {
        std::cout << "null" << std::endl;
      }
    }
  }
}